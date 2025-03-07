//
//  Request.swift
//  Osmium
//
//  Created by Francesco on 05/06/24.
//

import UIKit

extension ViewController {
    func getUserDefaultsValue<T>(key: String, defaultValue: T) -> T {
        return UserDefaults.standard.object(forKey: key) as? T ?? defaultValue
    }
    
    func sendPostRequest() {
        guard let urlText = urlTextField.text, !urlText.isEmpty else {
            showAlert(title: "Error", message: "Please enter a valid URL")
            return
        }
        
        guard let url = URL(string: UserDefaults.standard.string(forKey: "requestURL") ?? "") else {
            showAlert(title: "Error", message: "Invalid API URL")
            return
        }
        
        let validVideoQualities = ["144", "240", "360", "480", "720", "1080", "1440", "2160", "4320", "max"]
        let validAudioFormats = ["best", "mp3", "ogg", "wav", "opus"]
        let validAudioBitrates = ["320", "256", "128", "96", "64", "8"]
        let validFilenameStyles = ["classic", "pretty", "basic", "nerdy"]
        let validDownloadModes = ["auto", "audio", "mute"]
        let validVideoCodecs = ["h264", "av1", "vp9"]
        
        func cleanVideoQuality(_ quality: String) -> String {
            switch quality {
            case "8k":
                return "2160"
            case "4k":
                return "1440"
            default:
                return quality.replacingOccurrences(of: "p", with: "")
            }
        }
        
        func cleanAudioBitrate(_ bitrate: String) -> String {
            return bitrate.replacingOccurrences(of: "kbps", with: "").replacingOccurrences(of: "kb/s", with: "")
        }
        
        let videoQuality = cleanVideoQuality(getUserDefaultsValue(key: "videoQuality", defaultValue: "1080"))
        let audioFormat = getUserDefaultsValue(key: "audioFormat", defaultValue: "mp3")
        let audioBitrate = cleanAudioBitrate(getUserDefaultsValue(key: "audioBitrate", defaultValue: "128"))
        let filenameStyle = getUserDefaultsValue(key: "filenameStyle", defaultValue: "classic")
        let downloadMode = getUserDefaultsValue(key: "downloadMode", defaultValue: "auto")
        let youtubeVideoCodec = getUserDefaultsValue(key: "youtubeVideoCodec", defaultValue: "h264")
        
        let requestBody: [String: Any] = [
            "url": urlText,
            "videoQuality": validVideoQualities.contains(videoQuality) ? videoQuality : "1080",
            "audioFormat": validAudioFormats.contains(audioFormat) ? audioFormat : "mp3",
            "audioBitrate": validAudioBitrates.contains(audioBitrate) ? audioBitrate : "128",
            "filenameStyle": validFilenameStyles.contains(filenameStyle) ? filenameStyle : "classic",
            "downloadMode": validDownloadModes.contains(downloadMode) ? downloadMode : "auto",
            "youtubeVideoCodec": validVideoCodecs.contains(youtubeVideoCodec) ? youtubeVideoCodec : "h264",
            
            "alwaysProxy": getUserDefaultsValue(key: "alwaysProxy", defaultValue: false),
            "disableMetadata": getUserDefaultsValue(key: "disableMetadata", defaultValue: false),
            "tiktokFullAudio": getUserDefaultsValue(key: "tiktokFullAudio", defaultValue: false),
            "tiktokH265": getUserDefaultsValue(key: "tiktokH265", defaultValue: false),
            "twitterGif": getUserDefaultsValue(key: "twitterGif", defaultValue: true),
            "youtubeHLS": getUserDefaultsValue(key: "youtubeHLS", defaultValue: false)
        ]
        
        if debug {
            writeToConsole("Request Body:")
            requestBody.forEach { key, value in
                writeToConsole("\(key): \(value)")
            }
        }
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: requestBody) else {
            showAlert(title: "Error", message: "Failed to process request")
            return
        }
        
        var request = URLRequest(url: url)
        if debug {
            writeToConsole("Sending request to: \(url)")
        }
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData
        
        if let authKey = UserDefaults.standard.string(forKey: "authKey"),
           let authType = UserDefaults.standard.string(forKey: "authType") {
            let authValue = "\(authType) \(authKey)"
            request.setValue(authValue, forHTTPHeaderField: "Authorization")
            
            if debug {
                writeToConsole("Authorization Header: \(authValue)")
            }
        }
        
        let task = URLSession.shared.dataTask(with: request) { [weak self] data, _, error in
            guard let self = self else { return }
            
            if let error = error {
                self.writeToConsole("Error: \(error.localizedDescription)")
                self.showAlert(title: "Error", message: "Failed to process request")
                return
            }
            
            guard let data = data else {
                self.writeToConsole("No data")
                self.showAlert(title: "Error", message: "No data received")
                return
            }
            
            if self.debug {
                if let responseString = String(data: data, encoding: .utf8) {
                    self.writeToConsole("Response: \(responseString)")
                } else {
                    self.writeToConsole("Unable to convert response data to string")
                }
            }
            
            do {
                guard let jsonObject = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let status = jsonObject["status"] as? String else {
                    throw NSError(domain: "ParsingError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to extract status from JSON"])
                }
                self.writeToConsole("Response Status: \(status)")
                
                switch status {
                case "redirect", "stream", "tunnel":
                    guard let mediaURLString = jsonObject["url"] as? String else {
                        throw NSError(domain: "ParsingError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to extract URL or filename from JSON"])
                    }
                    self.saveMedia ? self.saveMediaToDocumentsFolder(urlString: mediaURLString) : self.openURLInSafari(urlString: mediaURLString)
                    self.writeToConsole(self.saveMedia ? "Saving media to temp folder..." : "Opening link...")
                case "picker":
                    self.writeToConsole("Opening Image Picker...")
                    self.handlePickerResponse(jsonObject)
                case "error":
                    if let errorObject = jsonObject["error"] as? [String: Any],
                       let errorCode = errorObject["code"] as? String {
                        self.writeToConsole("Error: \(errorCode)")
                        self.showAlert(title: "Error", message: "API returned an error: \(errorCode)")
                    } else {
                        self.writeToConsole("Unknown error in response")
                        self.showAlert(title: "Error", message: "Unknown error in API response")
                    }
                    
                default:
                    self.writeToConsole("Unexpected status in response: \(status)")
                    self.showAlert(title: "Error", message: "Unexpected status in response")
                }
            } catch {
                self.writeToConsole("Error: \(error.localizedDescription)")
                self.showAlert(title: "Error", message: "Failed to parse response")
            }
        }
        task.resume()
    }
}

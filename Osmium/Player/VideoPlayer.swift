//
//  VideoPlayer.swift
//  Osmium
//
//  Created by Francesco on 29/05/24.
//

import UIKit
import AVKit
import MobileCoreServices
import PhotosUI

class VideoPlayerViewController: UIViewController, AVPictureInPictureControllerDelegate, UIImagePickerControllerDelegate & UINavigationControllerDelegate {
    
    @IBOutlet weak var videoView: UIView!
    
    var player: AVPlayer?
    var playerViewController: AVPlayerViewController?
    var videoURL: URL?
    var pipController: AVPictureInPictureController?
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    @IBAction func selectVideoButtonPressed(_ sender: UIButton) {
        let alertController = UIAlertController(title: "Select Media", message: "Choose a source to select a video", preferredStyle: .actionSheet)
        
        let galleryIcon = UIImage(systemName: "photo.on.rectangle")
        let documentIcon = UIImage(systemName: "doc")
        
        let galleryAction = UIAlertAction(title: "Gallery", style: .default) { _ in
            self.presentImagePicker()
        }
        galleryAction.setValue(galleryIcon, forKey: "image")
        
        let documentAction = UIAlertAction(title: "Documents", style: .default) { _ in
            self.presentDocumentPicker()
        }
        documentAction.setValue(documentIcon, forKey: "image")
        
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
        
        alertController.addAction(galleryAction)
        alertController.addAction(documentAction)
        alertController.addAction(cancelAction)
        
        present(alertController, animated: true, completion: nil)
    }
    
    func presentImagePicker() {
        if UIImagePickerController.isSourceTypeAvailable(.photoLibrary) {
            let imagePickerController = UIImagePickerController()
            imagePickerController.delegate = self
            imagePickerController.mediaTypes = [kUTTypeMovie as String]
            imagePickerController.sourceType = .photoLibrary
            present(imagePickerController, animated: true, completion: nil)
        }
    }
    
    func presentDocumentPicker() {
        let documentPicker = UIDocumentPickerViewController(forOpeningContentTypes: [UTType.movie], asCopy: true)
        documentPicker.delegate = self
        documentPicker.modalPresentationStyle = .formSheet
        present(documentPicker, animated: true, completion: nil)
    }
    
    func playVideo() {
        guard let videoURL = videoURL else { return }
        
        let asset = AVAsset(url: videoURL)
        let playerItem = AVPlayerItem(asset: asset)
        player = AVPlayer(playerItem: playerItem)
        
        playerViewController = AVPlayerViewController()
        playerViewController?.player = player
        
        if let playerView = playerViewController?.view {
            playerView.frame = videoView.bounds
            videoView.addSubview(playerView)
        }
        
        player?.play()
        setupAudioSessionForPlayback()
        enablePiP()
    }
    
    func setupAudioSessionForPlayback() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playback, mode: .moviePlayback, options: [])
            try audioSession.setActive(true)
        } catch {
            print("Error setting audio session: \(error.localizedDescription)")
        }
    }
    
    func enablePiP() {
        guard let player = player,
              AVPictureInPictureController.isPictureInPictureSupported()
        else {
            print("PiP is not supported on this device.")
            return
        }
        
        pipController = AVPictureInPictureController(playerLayer: AVPlayerLayer(player: player))
        pipController!.delegate = self
        pipController!.canStartPictureInPictureAutomaticallyFromInline = true
        pipController!.startPictureInPicture()
    }
}

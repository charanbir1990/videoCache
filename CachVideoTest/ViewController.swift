//
//  ViewController.swift
//  CachVideoTest
//
//  Created by Charanbir sandhu on 28/09/20.
//  Copyright © 2020 Charan Sandhu. All rights reserved.
//

import UIKit

class ViewController: UIViewController {
    @IBOutlet weak var playerVw: UIView!

    override func viewDidLoad() {
        super.viewDidLoad()
        DispatchQueue.main.asyncAfter(deadline: .now()+1) {
            self.setupPlayer()
        }
    }

    private func setupPlayer() {
        let url = "https://scanmedia.s3-ap-southeast-1.amazonaws.com/152_13_p_e818603f33c4472b88210f50bd77f7ea.mp4"
        if let vw = Player.newPlayer(height: playerVw.frame.size.height, url: url) {
            playerVw.addSubview(vw)
            vw.play()
        }
    }

}


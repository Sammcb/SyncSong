//
//  SyncSongApp.swift
//  SyncSong
//
//  Created by Sam McBroom on 4/20/22.
//

import SwiftUI

@main
struct SyncSongApp: App {
	var body: some Scene {
		WindowGroup {
			MusicAuthorizationView()
		}
	}
}

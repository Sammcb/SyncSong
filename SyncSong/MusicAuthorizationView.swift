//
//  MusicAuthorizationView.swift
//  SyncSong
//
//  Created by Sam McBroom on 4/20/22.
//

import SwiftUI
import MusicKit

struct MusicAuthorizationView: View {
	@State private var authorized = false
	
	var body: some View {
		if authorized {
			SpotifyAuthorizationView()
		} else {
			Text("Apple Music Library access denied.")
				.onAppear {
					Task {
						let status = await MusicAuthorization.request()
						let libraryEnabled = try! await MusicSubscription.current.hasCloudLibraryEnabled
						authorized = status == .authorized && libraryEnabled
					}
				}
		}
	}
}

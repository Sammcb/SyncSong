//
//  SpotifyAuthorizationView.swift
//  SyncSong
//
//  Created by Sam McBroom on 4/29/22.
//

import SwiftUI

struct Spotify {
	static let clientSecret = Bundle.main.object(forInfoDictionaryKey: "SPOTIFY_SECRET") as! String
	static let callback = "https://www.sammcb.com/syncsong/spotify-callback"
	static let clientId = Bundle.main.object(forInfoDictionaryKey: "SPOTIFY_CLIENT") as! String
	static let scopes = "user-read-private user-read-email playlist-read-private playlist-read-collaborative"
	static let state = UUID().uuidString.replacingOccurrences(of: "-", with: "").dropLast(16).lowercased()
	static var authURL: URL {
		var authComponents = URLComponents()
		authComponents.scheme = "https"
		authComponents.host = "accounts.spotify.com"
		authComponents.path = "/authorize"
		authComponents.queryItems = [
			URLQueryItem(name: "response_type", value: "code"),
			URLQueryItem(name: "client_id", value: clientId),
			URLQueryItem(name: "scope", value: scopes),
			URLQueryItem(name: "redirect_uri", value: callback),
			URLQueryItem(name: "state", value: state)
		]
		return authComponents.url!
	}
	
	struct TokenResponse: Codable {
		let expires_in: Int
		let token_type: String
		let refresh_token: String
		let scope: String
		let access_token: String
	}
}

struct SpotifyAuthorizationView: View {
	@StateObject private var spotifyData = SpotifyData()
	@State private var authorized = false
	
	func requestAccessToken(code: String) async throws -> Spotify.TokenResponse {
		var components = URLComponents()
		components.scheme = "https"
		components.host = "accounts.spotify.com"
		components.path = "/api/token"
		var request = URLRequest(url: components.url!)
		request.httpMethod = "POST"
		let body = "grant_type=authorization_code&code=\(code)&redirect_uri=\(Spotify.callback)"
		request.httpBody = body.data(using: .utf8)!
		let authorization = "\(Spotify.clientId):\(Spotify.clientSecret)".data(using: .utf8)!.base64EncodedString()
		request.setValue("Basic \(authorization)", forHTTPHeaderField: "Authorization")
		request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
		let (data, _) = try await URLSession.shared.data(for: request)
		
		return try JSONDecoder().decode(Spotify.TokenResponse.self, from: data)
	}
	
	var body: some View {
		if authorized {
			SelectionView()
				.environmentObject(spotifyData)
		} else {
			Link("Spotify login", destination: Spotify.authURL)
				.onOpenURL { url in
					guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
						return
					}
					
					guard let queryItems = components.queryItems, queryItems.count == 2 else {
						return
					}
					
					guard let code = queryItems.first?.value, let state = queryItems.last?.value else {
						return
					}
					
					guard state == Spotify.state else {
						return
					}
					
					Task {
						do {
							let tokenResponse = try await requestAccessToken(code: code)
							spotifyData.authExpiration = Calendar.current.date(byAdding: .second, value: tokenResponse.expires_in, to: Date())!
							spotifyData.refreshToken = tokenResponse.refresh_token
							spotifyData.userToken = tokenResponse.access_token
							authorized = true
						} catch {
							print(error)
						}
					}
				}
		}
	}
}

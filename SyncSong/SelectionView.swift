//
//  SelectionView.swift
//  SyncSong
//
//  Created by Sam McBroom on 4/20/22.
//

import SwiftUI
import MusicKit

struct LibraryPlaylistsResponse: Codable {
	struct Playlist: Codable {
		struct Attributes: Codable {
			let canEdit: Bool
			let name: String
		}
		let id: String
		let href: String
		let attributes: Attributes
	}
	
	let next: String?
	let data: [Playlist]
}

struct PlaylistTracksResponse: Codable {
	struct Track: Codable {
		struct Attributes: Codable {
			struct PlayParams: Codable {
				let catalogId: String
			}
			
			let artistName: String
			let name: String
			let albumName: String
			let playParams: PlayParams?
		}
		
		let id: String
		let attributes: Attributes
	}
	
	let next: String?
	let data: [Track]
}

struct CatalogTracksResponse: Codable {
	struct Song: Codable {
		struct Attributes: Codable {
			struct PlayParams: Codable {
				let id: String
			}
			
			let artistName: String
			let name: String
			let isrc: String
			let albumName: String
			let playParams: PlayParams?
		}
		
		let id: String
		let attributes: Attributes
	}
	
	let data: [Song]
}

struct SearchResponse: Codable {
	struct Results: Codable {
		let songs: CatalogTracksResponse?
	}
	
	let results: Results
}

struct MusicPlaylist: Hashable, Identifiable {
	let id: String
	let name: String
	var songs: [MusicSong]
	
	init(_ playlist: LibraryPlaylistsResponse.Playlist) {
		self.id = playlist.id
		self.name = playlist.attributes.name
		self.songs = []
	}
}

struct MusicSong: Hashable, Identifiable {
	let id: String
	let name: String
	let artist: String
	let album: String
	let isrc: String
	
	init(_ track: CatalogTracksResponse.Song) {
		self.id = track.id
		self.name = track.attributes.name
		self.artist = track.attributes.artistName
		self.album = track.attributes.albumName
		self.isrc = track.attributes.isrc
	}
}

struct SpotifyPlaylistResponse: Codable {
	struct Playlist: Codable {
		let collaborative: Bool
		let id: String
		let name: String
	}
	
	let items: [Playlist]
	let next: String?
}

struct SpotifyPlaylistTracksResponse: Codable {
	struct TrackWrapper: Codable{
		struct Track: Codable {
			struct Album: Codable {
				let name: String
			}
			
			struct Artist: Codable {
				let name: String
			}
			
			struct ExternalIds: Codable {
				let isrc: String
			}
			
			let id: String
			let name: String
			let album: Album
			let artists: [Artist]
			let external_ids: ExternalIds
		}
		
		let track: Track
	}
	
	
	let items: [TrackWrapper]
	let next: String?
}

struct SpotifyPlaylist: Hashable, Identifiable {
	let name: String
	let collaborative: Bool
	var songs: [SpotifySong]
	let id: String
	
	init(_ playlist: SpotifyPlaylistResponse.Playlist) {
		self.name = playlist.name
		self.collaborative = playlist.collaborative
		self.songs = []
		self.id = playlist.id
	}
}

struct SpotifySong: Hashable, Identifiable {
	let id: String
	let name: String
	let artist: String
	let album: String
	let isrc: String
	
	init(_ track: SpotifyPlaylistTracksResponse.TrackWrapper.Track) {
		self.id = track.id
		self.name = track.name
		self.artist = track.artists.first?.name ?? "Unknown"
		self.album = track.album.name
		self.isrc = track.external_ids.isrc
	}
}

class SpotifyData: ObservableObject {
	private let scheme = "https"
	private let host = "api.spotify.com"
	var authExpiration = Date()
	var refreshToken = ""
	var userToken = ""
	@Published var playlists: [SpotifyPlaylist] = []
	
	func getPlaylists(at path: String) async throws -> SpotifyPlaylistResponse {
		var components = URLComponents(string: path)!
		components.scheme = scheme
		components.host = host
		if components.queryItems == nil {
			// Playlist query limit = 50
			components.queryItems = [
				URLQueryItem(name: "limit", value: "50")
			]
		}
		var request = URLRequest(url: components.url!)
		request.httpMethod = "GET"
		request.setValue("Bearer \(userToken)", forHTTPHeaderField: "Authorization")
		request.setValue("application/json", forHTTPHeaderField: "Content-Type")
		let (data, _) = try! await URLSession.shared.data(for: request)
		
		return try JSONDecoder().decode(SpotifyPlaylistResponse.self, from: data)
	}
	
	func getPlaylistTracks(at path: String) async throws -> SpotifyPlaylistTracksResponse {
		var components = URLComponents(string: path)!
		components.scheme = scheme
		components.host = host
		if components.queryItems == nil {
			// Playlist track query limit = 50
			components.queryItems = [
				URLQueryItem(name: "limit", value: "50")
			]
		}
		var request = URLRequest(url: components.url!)
		request.httpMethod = "GET"
		request.setValue("Bearer \(userToken)", forHTTPHeaderField: "Authorization")
		request.setValue("application/json", forHTTPHeaderField: "Content-Type")
		let (data, _) = try! await URLSession.shared.data(for: request)
		
		return try JSONDecoder().decode(SpotifyPlaylistTracksResponse.self, from: data)
	}
}

class MusicData: ObservableObject {
	private let scheme = "https"
	private let host = "api.music.apple.com"
	@Published var playlists: [MusicPlaylist] = []
	
	func getPlaylists(at path: String) async throws -> LibraryPlaylistsResponse {
		var components = URLComponents(string: path)!
		components.scheme = scheme
		components.host = host
		let request = MusicDataRequest(urlRequest: URLRequest(url: components.url!))
		
		let response = try await request.response()
		
		return try JSONDecoder().decode(LibraryPlaylistsResponse.self, from: response.data)
	}
	
	func getPlaylistTracks(at path: String) async throws -> PlaylistTracksResponse {
		var components = URLComponents(string: path)!
		components.scheme = scheme
		components.host = host
		let queryItems = components.queryItems ?? []
		// Playlist track query limit = 100
		components.queryItems = [
			URLQueryItem(name: "limit", value: "100")
		]
		components.queryItems!.append(contentsOf: queryItems)
		let request = MusicDataRequest(urlRequest: URLRequest(url: components.url!))
		
		let response = try await request.response()
		
		return try JSONDecoder().decode(PlaylistTracksResponse.self, from: response.data)
	}
	
	func getCatalogTrack(for ids: [String]) async throws -> CatalogTracksResponse {
		var components = URLComponents()
		components.scheme = scheme
		components.host = host
		components.path = "/v1/catalog/us/songs"
		components.queryItems = [
			URLQueryItem(name: "ids", value: ids.joined(separator: ","))
		]
		let request = MusicDataRequest(urlRequest: URLRequest(url: components.url!))
		
		let response = try await request.response()
		
		return try JSONDecoder().decode(CatalogTracksResponse.self, from: response.data)
	}
	
	func getCatalogTrack(by isrcs: [String]) async throws -> CatalogTracksResponse {
		var components = URLComponents()
		components.scheme = scheme
		components.host = host
		components.path = "/v1/catalog/us/songs"
		components.queryItems = [
			URLQueryItem(name: "filter[isrc]", value: isrcs.joined(separator: ","))
		]
		let request = MusicDataRequest(urlRequest: URLRequest(url: components.url!))
		
		let response = try await request.response()
		
		return try JSONDecoder().decode(CatalogTracksResponse.self, from: response.data)
	}
	
	func createPlaylist(named name: String) async throws -> LibraryPlaylistsResponse {
		var components = URLComponents()
		components.scheme = scheme
		components.host = host
		components.path = "/v1/me/library/playlists"
		var urlRequest = URLRequest(url: components.url!)
		urlRequest.httpMethod = "POST"
		let body = [
			"attributes": [
				"name": name
			]
		]
		urlRequest.httpBody = try JSONSerialization.data(withJSONObject: body)
		let request = MusicDataRequest(urlRequest: urlRequest)
		
		let response = try await request.response()
		
		return try JSONDecoder().decode(LibraryPlaylistsResponse.self, from: response.data)
	}
	
	func add(_ tracks: [MusicSong], to playlist: LibraryPlaylistsResponse.Playlist) async throws {
		var components = URLComponents()
		components.scheme = scheme
		components.host = host
		components.path = "/v1/me/library/playlists/\(playlist.id)/tracks"
		var urlRequest = URLRequest(url: components.url!)
		urlRequest.httpMethod = "POST"
		let body = ["data": tracks.map({ ["id": $0.id, "type": "songs"] })]
		urlRequest.httpBody = try JSONSerialization.data(withJSONObject: body)
		let request = MusicDataRequest(urlRequest: urlRequest)
		
		let _ = try await request.response()
	}
	
	func equivalentSongs(for songId: String) async throws -> CatalogTracksResponse {
		var components = URLComponents()
		components.scheme = scheme
		components.host = host
		components.path = "/v1/catalog/us/songs"
		components.queryItems = [
			URLQueryItem(name: "filter[equivalents]", value: songId)
		]
		let request = MusicDataRequest(urlRequest: URLRequest(url: components.url!))
		
		let response = try await request.response()
		
		return try JSONDecoder().decode(CatalogTracksResponse.self, from: response.data)
	}
	
	func search(for songName: String) async throws -> SearchResponse {
		var components = URLComponents()
		components.scheme = scheme
		components.host = host
		components.path = "/v1/catalog/us/search"
		components.queryItems = [
			URLQueryItem(name: "types", value: "songs"),
			URLQueryItem(name: "term", value: songName)
		]
		let request = MusicDataRequest(urlRequest: URLRequest(url: components.url!))
		
		let response = try await request.response()
		
		return try JSONDecoder().decode(SearchResponse.self, from: response.data)
	}
}

struct SelectionView: View {
	@StateObject private var musicData = MusicData()
	@EnvironmentObject private var spotifyData: SpotifyData
	@State private var selectedMusicPlaylist: MusicPlaylist?
	@State private var selectedSpotifyPlaylist: SpotifyPlaylist?
	@State private var copySpotifyPlaylist: SpotifyPlaylist?
	@State private var alert = ""
	
	var body: some View {
		VStack {
			Picker("Apple Music", selection: $selectedMusicPlaylist) {
				ForEach(musicData.playlists) { playlist in
					Text(playlist.name).tag(playlist as MusicPlaylist?)
				}
			}
			
			List {
				ForEach(selectedMusicPlaylist?.songs ?? []) { song in
					Text("\(song.name) -- \(song.artist) -- \(song.album)")
				}
			}
			
			Picker("Spotify", selection: $selectedSpotifyPlaylist) {
				ForEach(spotifyData.playlists, id: \.self) { playlist in
					Text("\(playlist.name) -- Songs: \(playlist.songs.count)").tag(playlist as SpotifyPlaylist?)
				}
			}
			
			List {
				ForEach(selectedSpotifyPlaylist?.songs ?? []) { song in
					Text("\(song.name) -- \(song.artist) -- \(song.album)")
				}
			}
			
			HStack {
				Button {
					Task{
						do {
							guard let playlist = selectedSpotifyPlaylist else {
								return
							}
							
							var unavailableSongs: [String] = []
							
							// Song query limit = 25
							let batchSize = 25
							let spotifyTracks = playlist.songs
							var songs: [MusicSong] = []
							for trackIndex in stride(from: 0, to: spotifyTracks.count, by: batchSize) {
								let endIndex = min(trackIndex + batchSize, spotifyTracks.count)
								let trackBatch = spotifyTracks[trackIndex..<endIndex]
								let batchIds = trackBatch.map({ $0.isrc })
								
								let catalogTracks = try await musicData.getCatalogTrack(by: batchIds).data
								
								var additionalSongs: [MusicSong] = []
								var replaced: [String] = []
								for catalogTrack in catalogTracks {
									// ISRC can match multiple songs, so only include one
									if additionalSongs.map({ $0.isrc }).contains(catalogTrack.attributes.isrc) {
										continue
									}
									
									// If playParams does not exist, then the song is not playable
									if catalogTrack.attributes.playParams == nil {
										// See if we can find an equivalent song
										let equivalent = try await musicData.equivalentSongs(for: catalogTrack.id).data
										guard let replacementTrack = equivalent.first, replacementTrack.attributes.playParams != nil else {
											continue
										}
										
										if additionalSongs.map({ $0.isrc }).contains(replacementTrack.attributes.isrc) {
											continue
										}
										
										replaced.append(catalogTrack.attributes.isrc)
										additionalSongs.append(MusicSong(replacementTrack))
										continue
									}
									
									additionalSongs.append(MusicSong(catalogTrack))
								}
								
								// In rare cases, ISRC does nto match between Apple Music and Spotify
								if additionalSongs.count < batchIds.count {
									let missingTracks = trackBatch.filter({ spotifyTrack in
										!additionalSongs.contains(where: { $0.isrc == spotifyTrack.isrc }) && !replaced.contains(where: { $0 == spotifyTrack.isrc })
									})
									for missingTrack in missingTracks {
										// Run a search to see if we can find a match in Apple Music
										let search = try await musicData.search(for: "\(missingTrack.name) \(missingTrack.artist)").results
										
										guard let searchSongs = search.songs?.data else {
											unavailableSongs.append("\(missingTrack.name) -- \(missingTrack.artist) -- \(missingTrack.album)")
											continue
										}
										
										if let replacementTrack = searchSongs.first(where: { $0.attributes.name == missingTrack.name && $0.attributes.playParams != nil }) {
											additionalSongs.append(MusicSong(replacementTrack))
										}
									}
								}
								
								songs.append(contentsOf: additionalSongs)
							}
							
							let createdPlaylistResponse = try await musicData.createPlaylist(named: playlist.name).data
							guard let createdPlaylist = createdPlaylistResponse.first else {
								return
							}

							try await musicData.add(songs, to: createdPlaylist)
							
							alert = unavailableSongs.joined(separator: "\n")
						} catch {
							print(error)
						}
					}
				} label: {
					Label("Create Apple Music playlist from Spotify playlist", systemImage: "plus")
				}
				
				Button {
					print("new spotify")
				} label: {
					Label("Create Spotify playlist from Apple Music playlist", systemImage: "plus")
				}
			}
			
			Text(alert)
				.foregroundColor(.red)
		}
		.task {
			do {
				// Get Apple Music playlists
				var next: String? = "/v1/me/library/playlists"
				repeat {
					let musicPlaylistsResponse = try await musicData.getPlaylists(at: next!)
					next = musicPlaylistsResponse.next
					
					for musicPlaylist in musicPlaylistsResponse.data {
						let playlist = MusicPlaylist(musicPlaylist)
						musicData.playlists.append(playlist)
					}
				} while next != nil
				
				// Get Spotify Playlists
				next = "/v1/me/playlists"
				repeat {
					let spotifyPlaylistResponse = try await spotifyData.getPlaylists(at: next!)
					next = spotifyPlaylistResponse.next
					
					for spotifyPlaylist in spotifyPlaylistResponse.items {
						let playlist = SpotifyPlaylist(spotifyPlaylist)
						spotifyData.playlists.append(playlist)
					}
				} while next != nil
			} catch {
				print(error)
			}
		}
		.task(id: selectedMusicPlaylist?.id) {
			do {
				guard var playlist = selectedMusicPlaylist else {
					return
				}
				
				// Get actual playlists songs
				var tracks: [PlaylistTracksResponse.Track] = []
				var next: String? = "/v1/me/library/playlists/\(playlist.id)/tracks"
				repeat {
					let tracksResponse = try await musicData.getPlaylistTracks(at: next!)
					next = tracksResponse.next
					
					tracks.append(contentsOf: tracksResponse.data)
				} while next != nil
				
				// Remove old songs from playlist
				playlist.songs.removeAll(where: { song in
					!tracks.contains(where: { $0.attributes.playParams?.catalogId == song.id })
				})
				
				// Find new songs we need to get data for
				let extraTracks = tracks.filter({ track in
					track.attributes.playParams != nil && !playlist.songs.contains(where: { $0.id == track.attributes.playParams?.catalogId })
				})
				
				// Song query limit = 300
				let batchSize = 300
				for trackIndex in stride(from: 0, to: extraTracks.count, by: batchSize) {
					let endIndex = min(trackIndex + batchSize, extraTracks.count)
					let trackBatch = extraTracks[trackIndex..<endIndex]
					let batchIds = trackBatch.map({ $0.attributes.playParams!.catalogId })
					
					let catalogTracks = try await musicData.getCatalogTrack(for: batchIds).data
					
					for catalogTrack in catalogTracks {
						let song = MusicSong(catalogTrack)
						playlist.songs.append(song)
					}
				}
				
				if playlist == selectedMusicPlaylist {
					return
				}
				
				selectedMusicPlaylist = playlist
				musicData.playlists[musicData.playlists.firstIndex(where: { $0.id == playlist.id })!] = playlist
			} catch {
				print(error)
			}
		}
		.task(id: selectedSpotifyPlaylist?.id) {
			do  {
				guard var playlist = selectedSpotifyPlaylist else {
					return
				}
				
				// Get actual playlists songs
				var tracks: [SpotifyPlaylistTracksResponse.TrackWrapper.Track] = []
				var next: String? = "/v1/playlists/\(playlist.id)/tracks"
				repeat {
					let tracksResponse = try await spotifyData.getPlaylistTracks(at: next!)
					next = tracksResponse.next
					
					tracks.append(contentsOf: tracksResponse.items.map({ $0.track }))
				} while next != nil
				
				// Remove old songs from playlist
				playlist.songs.removeAll(where: { song in
					!tracks.contains(where: { $0.id == song.id })
				})
				
				// Find new songs we need to get data for
				let extraTracks = tracks.filter({ track in
					!playlist.songs.contains(where: { $0.id == track.id })
				})
				
				for track in extraTracks {
					let song = SpotifySong(track)
					playlist.songs.append(song)
				}
				
				if playlist == selectedSpotifyPlaylist {
					return
				}
				
				selectedSpotifyPlaylist = playlist
				spotifyData.playlists[spotifyData.playlists.firstIndex(where: { $0.id == playlist.id })!] = playlist
			} catch {
				print(error)
			}
		}
	}
}

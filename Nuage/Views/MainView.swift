//
//  MainView.swift
//  Nuage
//
//  Created by Laurin Brandner on 26.12.19.
//  Copyright © 2019 Laurin Brandner. All rights reserved.
//

import SwiftUI
import Combine
import AppKit
import URLImage
import Introspect
import StackNavigationView
import SoundCloud

struct MainView: View {
    
    @State private var navigationSelection: Int? = 0
    @State private var playlists = [Playlist]()
    @State private var searchQuery = ""
    @State private var presentProfile = false
    @State private var subscriptions = Set<AnyCancellable>()
    
    @EnvironmentObject private var commands: Commands
    
    var body: some View {
        let stream = SoundCloud.shared.get(.stream())
        let streamView = PostList(for: stream).navigationTitle("Stream")
        
        let likes = SoundCloud.shared.$user.filter { $0 != nil}
            .flatMap { SoundCloud.shared.get(.trackLikes(of: $0!)) }
            .eraseToAnyPublisher()
        let likesView = TrackList(for: likes).navigationTitle("Likes")
        
        let history = SoundCloud.shared.get(.history())
        let historyView = TrackList(for: history).navigationTitle("History")
        
        let following = SoundCloud.shared.$user.filter { $0 != nil }
            .flatMap { SoundCloud.shared.get(.followings(of: $0!)) }
            .eraseToAnyPublisher()
        let followingView = UserGrid(for: following).navigationTitle("Following")
        
        return VStack(spacing: 0) {
//            let presentSearch = Binding(get: { searchQuery.count > 0 },
//                                        set: { presented in
//                                            if !presented {
//                                                searchQuery = ""
//                                            }
//                                        })
            let stackItem: Binding<Int?> = Binding(get: { presentProfile ? 1 : (searchQuery.count > 0 ? 2 : nil) },
                                                      set: { value in
                                                        if value == nil {
                                                            presentProfile = false
                                                            searchQuery = ""
                                                        }
                                                      })
            
            StackNavigationView(selection: $navigationSelection) {
                List {
                    sidebarNavigationLink(title: "Stream", imageName: "bolt.horizontal.fill", destination: streamView, tag: 0)
                    Section(header: Text("Library")) {
                        sidebarNavigationLink(title: "Likes", imageName: "heart.fill", destination: likesView, tag: 1)
                        sidebarNavigationLink(title: "History", imageName: "clock.fill", destination: historyView, tag: 2)
                        sidebarNavigationLink(title: "Following", imageName: "person.2.fill", destination: followingView, tag: 3)
                    }
                    Section(header: Text("Playlists")) {
                        ForEach(0..<playlists.count, id: \.self) { idx in
                            let playlist = playlists[idx]
                            let ids = SoundCloud.shared.get(.playlist(playlist.id))
                                .map { $0.trackIDs ?? [] }
                                .eraseToAnyPublisher()
                            let slice = { ids in
                                return SoundCloud.shared.get(.tracks(ids))
                            }

                            let playlistView = TrackList(for: ids, slice: slice).navigationTitle(playlist.title)
                            SidebarNavigationLink(playlist.title, destination: playlistView, tag: idx+4, selection: $navigationSelection)
                        }
                    }
                }
                .listStyle(SidebarListStyle())
            }
            .stack(item: stackItem) {
                if presentProfile {
                    UserDetail(user: SoundCloud.shared.user!)
                }
                else {
                    let search = SoundCloud.shared.get(.search(searchQuery))
                    SearchList(for: search)
                }
            }
            PlayerView()
        }
        .frame(minWidth: 800, minHeight: 400)
        .toolbar {
            ToolbarItem {
                TextField("􀊫 Search", text: $searchQuery)
                    .onExitCommand { searchQuery = "" }
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .frame(minWidth: 150)

            }
//            ToolbarItem {
//                MenuButton(label: Image(systemName: "arrow.up.arrow.down")) {
//                    Text("Recently Added")
//
//                }
//            }
            ToolbarItem {
                Button(action: { presentProfile = true }) {
                    HStack {
                        Text(SoundCloud.shared.user?.displayName ?? "Profile")
                            .bold()
                            .foregroundColor(.secondary)
                        RemoteImage(url: SoundCloud.shared.user?.avatarURL, cornerRadius: 15)
                            .frame(width: 30, height: 30)
                    }
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .onAppear {            
            SoundCloud.shared.get(.albumsAndPlaylists())
                .map { $0.collection }
                .replaceError(with: [])
                .receive(on: RunLoop.main)
                .sink { likes in
                    let playlists = likes.map { $0.item }
                    self.playlists = playlists
                    SoundCloud.shared.user?.playlists = playlists
                }
                .store(in: &self.subscriptions)
        }
    }
    
    @ViewBuilder private func sidebarNavigationLink<V: View>(title: String, imageName: String, destination: V, tag: Int) -> some View {
        SidebarNavigationLink(destination: destination, tag: tag, selection: $navigationSelection) {
            HStack {
                Image(systemName: imageName)
                    .frame(width: 20, alignment: .center)
                Text(title)
            }
        }
    }
    
}

//struct MainView_Previews: PreviewProvider {
//    static var previews: some View {
//        MainView()
//    }
//}

//
//  ContentView.swift
//  MuffinStoreJailed
//
//  Created by Mineek on 26/12/2024.
//

import SwiftUI

struct HeaderView: View {
    var body: some View {
        VStack {
            Text("MuffinStore Jailed")
                .font(.largeTitle)
                .fontWeight(.bold)
            Text("by @mineekdev")
                .font(.caption)
        }
    }
}

struct FooterView: View {
    var body: some View {
        VStack {
            VStack {
                Image(systemName: "exclamationmark.triangle")
                    .foregroundStyle(.red)
                Text("Use at your own risk!")
                    .foregroundStyle(.yellow)
                Image(systemName: "exclamationmark.triangle")
                    .foregroundStyle(.red)
            }
            Text("I am not responsible for any damage, data loss, or any other issues caused by using this tool.")
                .font(.caption)
        }
    }
}

struct ContentView: View {
    @State var ipaTool: IPATool?
    
    @State var appleId: String = ""
    @State var password: String = ""
    @State var code: String = ""
    
    @State var isAuthenticated: Bool = false
    @State var isDowngrading: Bool = false
    
    @State var appLink: String = ""
    
    var body: some View {
        VStack {
            HeaderView()
            Spacer()
            if !isAuthenticated {
                VStack {
                    Text("Log in to the App Store")
                        .font(.headline)
                        .fontWeight(.bold)
                    Text("Your credentials will be sent directly to Apple.")
                        .font(.caption)
                }
                TextField("Apple ID", text: $appleId)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding()
                .autocapitalization(.none)
                .disableAutocorrection(true)
                SecureField("Password", text: $password)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding()
                TextField("2FA Code", text: $code)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding()
                Button("Authenticate") {
                    if appleId.isEmpty || password.isEmpty || code.isEmpty {
                        return
                    }
                    let finalPassword = password + code
                    ipaTool = IPATool(appleId: appleId, password: finalPassword)
                    let ret = ipaTool?.authenticate()
                    isAuthenticated = ret ?? false
                }
                .padding()
                
                HStack {
                    Image(systemName: "info.circle.fill")
                        .foregroundColor(.yellow)
                    Text("You WILL need to give a 2FA code to successfully log in.")
                }
            } else {
                if isDowngrading {
                    VStack {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                        Text("Please wait...")
                            .font(.headline)
                            .fontWeight(.bold)
                        Text("The app is being downgraded. This may take a while.")
                            .font(.caption)
                        
                        Button("Done (exit app)") {
                            exit(0) // scuffed
                        }
                        .padding()
                    }
                } else {
                    VStack {
                        Text("Downgrade an app")
                            .font(.headline)
                            .fontWeight(.bold)
                        Text("Enter the App Store link of the app you want to downgrade.")
                            .font(.caption)
                    }
                    TextField("App share Link", text: $appLink)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .padding()
                    Button("Downgrade") {
                        if appLink.isEmpty {
                            return
                        }
                        var appLinkParsed = appLink
                        appLinkParsed = appLinkParsed.components(separatedBy: "id").last ?? ""
                        for char in appLinkParsed {
                            if !char.isNumber {
                                appLinkParsed = String(appLinkParsed.prefix(upTo: appLinkParsed.firstIndex(of: char)!))
                                break
                            }
                        }
                        print("App ID: \(appLinkParsed)")
                        isDowngrading = true
                        downgradeApp(appId: appLinkParsed, ipaTool: ipaTool!)
                    }
                    .padding()

                    Button("Log out and exit") {
                        isAuthenticated = false
                        EncryptedKeychainWrapper.nuke()
                        EncryptedKeychainWrapper.generateAndStoreKey()
                        sleep(3)
                        exit(0) // scuffed
                    }
                    .padding()
                }
            }
            Spacer()
            FooterView()
        }
        .padding()
        .onAppear {
            isAuthenticated = EncryptedKeychainWrapper.hasAuthInfo()
            print("Found \(isAuthenticated ? "auth" : "no auth") info in keychain")
            if isAuthenticated {
                guard let authInfo = EncryptedKeychainWrapper.getAuthInfo() else {
                    print("Failed to get auth info from keychain, logging out")
                    isAuthenticated = false
                    EncryptedKeychainWrapper.nuke()
                    EncryptedKeychainWrapper.generateAndStoreKey()
                    return
                }
                appleId = authInfo["appleId"]! as! String
                password = authInfo["password"]! as! String
                ipaTool = IPATool(appleId: appleId, password: password)
                let ret = ipaTool?.authenticate()
                print("Re-authenticated \(ret! ? "successfully" : "unsuccessfully")")
            } else {
                print("No auth info found in keychain, setting up by generating a key in SEP")
                EncryptedKeychainWrapper.generateAndStoreKey()
            }
        }
    }
}

#Preview {
    ContentView()
}

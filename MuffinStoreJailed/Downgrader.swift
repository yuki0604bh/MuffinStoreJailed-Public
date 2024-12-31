//
//  Downgrader.swift
//  MuffinStoreJailed
//
//  Created by Mineek on 19/10/2024.
//

import Foundation
import UIKit
import Telegraph
import Zip

func downgradeAppToVersion(appId: String, versionId: String, ipaTool: IPATool) {
    let path = ipaTool.downloadIPAForVersion(appId: appId, appVerId: versionId)
    print("IPA downloaded to \(path)")
    
    let tempDir = FileManager.default.temporaryDirectory
    var contents = try! FileManager.default.contentsOfDirectory(atPath: path)
    print("Contents: \(contents)")
    let destinationUrl = tempDir.appendingPathComponent("app.ipa")
    try! Zip.zipFiles(paths: contents.map { URL(fileURLWithPath: path).appendingPathComponent($0) }, zipFilePath: destinationUrl, password: nil, progress: nil)
    print("IPA zipped to \(destinationUrl)")
    let path2 = URL(fileURLWithPath: path)
    var appDir = path2.appendingPathComponent("Payload")
    for file in try! FileManager.default.contentsOfDirectory(atPath: appDir.path) {
        if file.hasSuffix(".app") {
            print("Found app: \(file)")
            appDir = appDir.appendingPathComponent(file)
            break
        }
    }
    let infoPlistPath = appDir.appendingPathComponent("Info.plist")
    let infoPlist = NSDictionary(contentsOf: infoPlistPath)!
    let appBundleId = infoPlist["CFBundleIdentifier"] as! String
    let appVersion = infoPlist["CFBundleShortVersionString"] as! String
    print("appBundleId: \(appBundleId)")
    print("appVersion: \(appVersion)")
    
    DispatchQueue.global(qos: .background).async {
        let server = Server()

        server.route(.GET, "signed.ipa", { _ in
            print("Serving signed.ipa")
            let signedIPAData = try Data(contentsOf: destinationUrl)
            return HTTPResponse(body: signedIPAData)
        })
        
        try! server.start(port: 9090)
        print("Server has started listening")
        
        DispatchQueue.main.async {
            print("Requesting app install")
            let finalURL = "https://api.palera.in/genPlist?bundleid=\(appBundleId)&name=\(appBundleId)&version=\(appVersion)&fetchurl=http://127.0.0.1:9090/signed.ipa"
            let finalURLfr = "itms-services://?action=download-manifest&url=" + finalURL.addingPercentEncoding(withAllowedCharacters: .alphanumerics)!
            UIApplication.shared.open(URL(string: finalURLfr)!)
        }
        
        while server.isRunning {
            sleep(1)
        }
        print("Server has stopped")
    }
}

func promptForVersionId(appId: String, versionIds: [String], ipaTool: IPATool) {
    let isiPad = UIDevice.current.userInterfaceIdiom == .pad
    let alert = UIAlertController(title: "Enter version ID", message: "Select a version to downgrade to", preferredStyle: isiPad ? .alert : .actionSheet)
    for versionId in versionIds {
        alert.addAction(UIAlertAction(title: versionId, style: .default, handler: { _ in
            downgradeAppToVersion(appId: appId, versionId: versionId, ipaTool: ipaTool)
        }))
    }
    alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
    UIApplication.shared.windows.first?.rootViewController?.present(alert, animated: true, completion: nil)
}

func showAlert(title: String, message: String) {
    let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
    alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
    UIApplication.shared.windows.first?.rootViewController?.present(alert, animated: true, completion: nil)
}

func getAllAppVersionIdsFromServer(appId: String, ipaTool: IPATool) {
    let serverURL = "https://apis.bilin.eu.org/history/"
    let url = URL(string: "\(serverURL)\(appId)")!
    let request = URLRequest(url: url)
    let task = URLSession.shared.dataTask(with: request) { data, response, error in
        if let error = error {
            DispatchQueue.main.async {
                showAlert(title: "Error", message: error.localizedDescription)
            }
            return
        }
        let json = try! JSONSerialization.jsonObject(with: data!) as! [String: Any]
        let versionIds = json["data"] as! [Dictionary<String, Any>]
        if versionIds.count == 0 {
            DispatchQueue.main.async {
                showAlert(title: "Error", message: "No version IDs, internal error maybe?")
            }
            return
        }
        DispatchQueue.main.async {
            let isiPad = UIDevice.current.userInterfaceIdiom == .pad
            let alert = UIAlertController(title: "Select a version", message: "Select a version to downgrade to", preferredStyle: isiPad ? .alert : .actionSheet)
            for versionId in versionIds {
                alert.addAction(UIAlertAction(title: "\(versionId["bundle_version"]!)", style: .default, handler: { _ in
                    downgradeAppToVersion(appId: appId, versionId: "\(versionId["external_identifier"]!)", ipaTool: ipaTool)
                }))
            }
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
            UIApplication.shared.windows.first?.rootViewController?.present(alert, animated: true, completion: nil)
        }
    }
    task.resume()
}

func downgradeApp(appId: String, ipaTool: IPATool) {
    let versionIds = ipaTool.getVersionIDList(appId: appId)
    var selectedVersion = ""
    let isiPad = UIDevice.current.userInterfaceIdiom == .pad
    
    let alert = UIAlertController(title: "Version ID", message: "Do you want to enter the version ID manually or request the list of version IDs from the server?", preferredStyle: isiPad ? .alert : .actionSheet)
    alert.addAction(UIAlertAction(title: "Manual", style: .default, handler: { _ in
        promptForVersionId(appId: appId, versionIds: versionIds, ipaTool: ipaTool)
    }))
    alert.addAction(UIAlertAction(title: "Server", style: .default, handler: { _ in
        getAllAppVersionIdsFromServer(appId: appId, ipaTool: ipaTool)
    }))
    alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
    UIApplication.shared.windows.first?.rootViewController?.present(alert, animated: true, completion: nil)
}

//
//  PluginHelper.swift
//  StarConsoleLink
//
//  Created by 星星 on 16/1/28.
//  Copyright © 2016年 AbsoluteStar. All rights reserved.
//

import Foundation
import AppKit


// MARK: - File Cache & Find File

// [workspacePath : [fileName : filePath]]
var filePathCache = [String : [String : String]]()

func findFile(workspacePath : String, _ fileName : String) -> String? {
    var thisWorkspaceCache = filePathCache[workspacePath] ?? [:]
    if let result = thisWorkspaceCache[fileName] {
        if NSFileManager.defaultManager().fileExistsAtPath(result) {
            return result
        }
    }
    
    var searchPath = workspacePath
    var prevSearchPath : String? = nil
    var searchCount = 0
    while true {
        if let result = findFile(fileName, searchPath, prevSearchPath) where !result.isEmpty {
            thisWorkspaceCache[fileName] = result
            filePathCache[workspacePath] = thisWorkspaceCache
            return result
        }
        
        prevSearchPath = searchPath
        searchPath = searchPath.OCString.stringByDeletingLastPathComponent
        searchCount += 1
        let searchPathCount = searchPath.componentsSeparatedByString("/").count
        if searchPathCount <= 3 || searchCount >= 2 {
            return nil
        }
    }
}

func findFile(fileName : String, _ searchPath : String, _ prevSearchPath : String?) -> String? {
    let args = (prevSearchPath == nil ?
        ["-L", searchPath, "-name", fileName, "-print", "-quit"] :
        ["-L", searchPath, "-name", prevSearchPath!, "-prune", "-o", "-name", fileName, "-print", "-quit"])
    return PluginHelper.runShellCommand("/usr/bin/find", arguments: args)
}


// MARK: - PluginHelper

class PluginHelper: NSObject {
    
    static func runShellCommand(launchPath: String, arguments: [String]) -> String? {
        let pipe = NSPipe()
        let task = NSTask()
        task.launchPath = launchPath
        task.arguments = arguments
        task.standardOutput = pipe
        let file = pipe.fileHandleForReading
        task.launch()
        guard let result = NSString(data: file.readDataToEndOfFile(), encoding: NSUTF8StringEncoding)?.stringByTrimmingCharactersInSet(NSCharacterSet.newlineCharacterSet()) else {
            return nil
        }
        return result as String
    }
    
    static func getViewByClassName(name: String, inContainer container: NSView) -> NSView? {
        
        guard let targetClass = NSClassFromString(name) else {
            return nil
        }
        for subview in container.subviews {
            if subview.isKindOfClass(targetClass) {
                return subview
            }
            if let view = getViewByClassName(name, inContainer: subview) {
                return view
            }
        }
        return nil
    }
}

extension PluginHelper {
    
    static func workspacePath() -> String? {
        
        if let workspacePath = StarFunctions.workspacePath() {
            return workspacePath
        }
        
        guard let anyClass = NSClassFromString("IDEWorkspaceWindowController") as? NSObject.Type,
            let windowControllers = anyClass.valueForKey("workspaceWindowControllers") as? [NSObject],
            let window = NSApp.keyWindow ?? NSApp.windows.first else {
                Logger.info("Failed to establish workspace path")
                return nil
        }
        var workspace: NSObject?
        for controller in windowControllers {
            if controller.valueForKey("window")?.isEqual(window) == true {
                workspace = controller.valueForKey("_workspace") as? NSObject
            }
        }
        
        guard let workspacePath = workspace?.valueForKeyPath("representingFilePath._pathString") as? NSString else {
            Logger.info("Failed to establish workspace path")
            return nil
        }
        
        return workspacePath.stringByDeletingLastPathComponent as String
    }
    
    // 代码台
    static func editorTextView(inWindow window: NSWindow? = NSApp.mainWindow) -> NSTextView? {
        guard let window = window,
            let windowController = window.windowController,
            let editor = windowController.valueForKeyPath("editorArea.lastActiveEditorContext.editor"),
            let textView = editor.valueForKey("textView") as? NSTextView else {
                return nil
        }
        
        return textView
    }
    
    // DVTSourceTextView 控制台
    static func consoleTextView(inWindow window: NSWindow? = NSApp.mainWindow) -> NSTextView? {
        guard let contentView = window?.contentView,
            let consoleTextView = PluginHelper.getViewByClassName("IDEConsoleTextView", inContainer: contentView) as? NSTextView else {
                return nil
        }
        return consoleTextView
    }
}

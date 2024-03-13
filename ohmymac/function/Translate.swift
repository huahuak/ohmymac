//
//  Translate.swift
//  WindowActionCallback
//
//  Created by huahua on 2023/8/25.
//

import Cocoa


// MARK: - get text
func getScreenText() -> String {
    return WindowAction.getSelectedText() ?? {
        executeCopy()
        Thread.sleep(forTimeInterval: 0.1)
        return getClipBordText() ?? ""
    }()
}

func executeCopy() {
    // Simulate Command+C key press
    let source = CGEventSource(stateID: .hidSystemState)
    let keyDownEvent = CGEvent(keyboardEventSource: source, virtualKey: 8, keyDown: true)
    let keyUpEvent = CGEvent(keyboardEventSource: source, virtualKey: 8, keyDown: false)
    keyDownEvent?.flags = .maskCommand
    keyUpEvent?.flags = .maskCommand
    keyDownEvent?.post(tap: .cghidEventTap)
    keyUpEvent?.post(tap: .cghidEventTap)
}

func getClipBordText() -> String? {
    let clipboardText = NSPasteboard.general.string(forType: .string)
    return clipboardText
}

// MARK: - translate
func translate(source: String, using: @escaping (String) -> Void) {
    do {
        let translator =  Process()
        translator.executableURL = URL(fileURLWithPath: "/bin/zsh")
        translator.arguments = ["-c", "echo '\(source)' | shortcuts run apple-translator -i - | tee"]
        let output = Pipe()
        translator.standardOutput = output
        try translator.run()
        let outputData = output.fileHandleForReading.readDataToEndOfFile()
        if let translated = String(data: outputData, encoding: .utf8) {
            let html =  createHTML(source: source, translated: translated)
            using(html)
        }
    } catch let error {
        debugPrint("run shortcut failed, \(error)")
    }
}


func createHTML(source: String, translated: String) -> String {
    var html = """
    <!DOCTYPE html>
    <html>
    
    <head>
      <meta charset="UTF-8">
      <title>Translation</title>
      <style>
         body {
          font-size: 20px;
          font-weight: 300;
          line-height: 32px;
        }
    
        #article {
          box-shadow: 0px 6px 12px 3px rgba(0, 0, 0, 0.2);
          background: white;
          min-height: 80ex;
          max-width: 100ex;
          margin: 22px auto;
        }
    
        #page {
          background-color: white;
          margin: auto 1.5rem;
          padding-top: 53px;
          padding-bottom: 45px;
    
        }
    
        .left {
          width: 50%;
          padding-right: 0.8rem;
          text-align: justify;
          word-wrap: break-word;
          border-right: 1px solid #12593f;
        }
    
        .right {
          width: 50%;
          padding-left: 0.8rem;
          word-break: break-all;
          word-wrap: break-word;
          border-left: 1px solid #12593f;
        }
    
        .box {
          display: flex;
        }
      </style>
    </head>
    
    <body style="background: rgb(220,220,220);">
      <div id="article">
        <div id="page">
          <div style="display: inline;">
    """
    let sourceSplit = source.split(separator: ".")
    let translatedSplit = translated.split(separator: "。")
    if sourceSplit.count == translatedSplit.count {
        zip(sourceSplit, translatedSplit).forEach( { (l, r) in
            html += """
                <div class="box">
                <div class="left">
                <p >\(l)</p>
                </div>
                <div class="right">
                <p style="color: rgb(10, 70, 85);  font-family: [Menlo, 'songti sc']; font-weight: normal">\(r)</p>
                </div>
                </div>
            """
        })
    } else {
        let sourceSplit = source.split(separator: "\n")
        let translatedSplit = translated.split(separator: "\n")
        if sourceSplit.count == translatedSplit.count {
            zip(sourceSplit, translatedSplit).forEach( { (l, r) in
                html += """
                    <div class="box">
                    <div class="left">
                    <p >\(l)</p>
                    </div>
                    <div class="right">
                    <p style="color: rgb(10, 70, 85);  font-family: [Menlo, 'songti sc']; font-weight: normal">\(r)</p>
                    </div>
                    </div>
                """
            })
        }
        else {
            html += """
            <div class="box">
            <div class="left">
            <p >\(source)</p>
            </div>
            <div class="right">
            <p style="color: rgb(10, 70, 85);  font-family: [Menlo, 'songti sc']; font-weight: normal">\(translated)</p>
            </div>
            </div>
        """
        }
    }
    html += """
                  </div>
                </div>
              </div>
            </body>
    
            </html>
    """
    return html
}

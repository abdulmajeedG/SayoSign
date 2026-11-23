import SwiftUI

// An app waiting to run inside SayoSign (Container.run) starts here instead of SayoSign.
if !Container.launchIfRequested() {
    SayoSignApp.main()
}

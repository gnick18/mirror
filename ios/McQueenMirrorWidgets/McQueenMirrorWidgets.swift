import SwiftUI
import WidgetKit

@main
struct McQueenMirrorWidgets: WidgetBundle {
    var body: some Widget {
        CommuteWidget()
        LockScreenBusWidget()
        MirrorDisplayControl()
    }
}

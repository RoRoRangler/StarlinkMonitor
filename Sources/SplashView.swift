import SwiftUI

struct SplashView: View {
    var body: some View {
        ZStack {
            Color.black.edgesIgnoringSafeArea(.all)
            
            Image("StarlinkSplash")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .edgesIgnoringSafeArea(.all)
            
            VStack {
                Spacer()
                Text("Starlink Monitor")
                    .font(.largeTitle)
                    .fontWeight(.heavy)
                    .foregroundColor(.white)
                    .shadow(radius: 10)
                    .padding(.bottom, 40)
            }
        }
        .frame(minWidth: 800, minHeight: 600)
    }
}

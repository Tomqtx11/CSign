import SwiftUI
import NimbleViews

struct DisclaimerView: View {
    @Binding var hasAcceptedDisclaimer: Bool
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Image("Glyph")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 100, height: 100)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 20)
                    
                    Text("⚠️ Điều khoản sử dụng")
                        .font(.title2.bold())
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.bottom, 10)
                    
                    Text("Bằng việc sử dụng ứng dụng CSign, bạn đồng ý và cam kết:\n\n• Chỉ sử dụng cho mục đích cá nhân, nghiên cứu và học tập.\n• Không sử dụng để vi phạm bản quyền hoặc bất kỳ hành vi trái pháp luật nào.\n• Người dùng tự chịu hoàn toàn trách nhiệm về mọi hành vi khi sử dụng ứng dụng.\n• Nhà phát triển không chịu trách nhiệm cho bất kỳ thiệt hại nào phát sinh từ việc sử dụng.\n\nNếu bạn không đồng ý, vui lòng nhấn \"Từ chối\" để thoát ứng dụng.")
                        .font(.body)
                        .padding(.horizontal)
                        
                    Spacer(minLength: 40)
                    
                    VStack(spacing: 12) {
                        Button {
                            hasAcceptedDisclaimer = true
                        } label: {
                            Text("Đồng ý")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.accentColor)
                                .cornerRadius(12)
                        }
                        
                        Button {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                exit(0)
                            }
                        } label: {
                            Text("Từ chối")
                                .font(.headline)
                                .foregroundColor(.red)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.red.opacity(0.1))
                                .cornerRadius(12)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 30)
                }
            }
            .interactiveDismissDisabled(true)
        }
    }
}

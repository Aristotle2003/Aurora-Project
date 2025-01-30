import SwiftUI
import TOCropViewController

struct ImagePicker: UIViewControllerRepresentable {
    
    @Binding var image: UIImage?
    var sourceType: UIImagePickerController.SourceType = .photoLibrary
    @Environment(\.presentationMode) var presentationMode // To dismiss the SwiftUI modal
    
    private let controller = UIImagePickerController()
    
    func makeCoordinator() -> Coordinator {
        return Coordinator(parent: self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate, TOCropViewControllerDelegate {
        
        let parent: ImagePicker
        
        init(parent: ImagePicker) {
            self.parent = parent
        }
        
        // MARK: UIImagePickerControllerDelegate Methods
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let selectedImage = info[.originalImage] as? UIImage {
                // Present TOCropViewController for cropping
                let cropVC = TOCropViewController(croppingStyle: .default, image: selectedImage)
                cropVC.delegate = self
                picker.present(cropVC, animated: true)
            }
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            // Dismiss UIImagePickerController when cancel is pressed
            picker.dismiss(animated: true) {
                self.parent.presentationMode.wrappedValue.dismiss() // Dismiss SwiftUI modal
            }
        }
        
        // MARK: TOCropViewControllerDelegate Methods
        func cropViewController(_ cropViewController: TOCropViewController, didCropTo image: UIImage, with cropRect: CGRect, angle: Int) {
            // Save cropped image and dismiss both controllers
            parent.image = image
            cropViewController.presentingViewController?.dismiss(animated: true) {
                self.parent.presentationMode.wrappedValue.dismiss() // Dismiss SwiftUI modal
            }
        }
        
        func cropViewController(_ cropViewController: TOCropViewController, didFinishCancelled cancelled: Bool) {
            // Dismiss cropping when cancelled
            cropViewController.presentingViewController?.dismiss(animated: true) {
                self.parent.presentationMode.wrappedValue.dismiss() // Dismiss SwiftUI modal
            }
        }
    }
    
    func makeUIViewController(context: Context) -> some UIViewController {
        controller.delegate = context.coordinator
        controller.sourceType = sourceType
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIViewControllerType, context: Context) {
        // No updates needed
    }
}

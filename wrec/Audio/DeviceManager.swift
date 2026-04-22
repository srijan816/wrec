import Foundation
import AVFoundation
import Combine

@MainActor
final class DeviceManager: ObservableObject {
    @Published var availableInputDevices: [AVCaptureDevice] = []
    @Published var selectedInputDevice: AVCaptureDevice?
    @Published var isHotSwapSupported: Bool = true

    init() {
        refreshDevices()
        setupRouteChangeObserver()
    }

    func refreshDevices() {
        let discoverySession = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInMicrophone, .externalUnknown],
            mediaType: .audio,
            position: .unspecified
        )
        availableInputDevices = discoverySession.devices

        if selectedInputDevice == nil {
            selectedInputDevice = AVCaptureDevice.default(for: .audio)
        }
    }

    func selectDevice(_ device: AVCaptureDevice) {
        selectedInputDevice = device
    }

    func selectDevice(byUID uid: String) {
        selectedInputDevice = availableInputDevices.first { $0.uniqueID == uid }
    }

    private func setupRouteChangeObserver() {
        NotificationCenter.default.addObserver(
            forName: .AVCaptureDeviceWasConnected,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.handleDeviceConnection()
            }
        }

        NotificationCenter.default.addObserver(
            forName: .AVCaptureDeviceWasDisconnected,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.handleDeviceDisconnection()
            }
        }
    }

    private func handleDeviceConnection() {
        refreshDevices()
    }

    private func handleDeviceDisconnection() {
        refreshDevices()
    }

    func getDeviceName(_ device: AVCaptureDevice) -> String {
        device.localizedName
    }

    func getDeviceUID(_ device: AVCaptureDevice) -> String {
        device.uniqueID
    }
}

//
//  MemberAvatarEditorSheet.swift
//  filmfreaks
//
//  Photo selection, lightweight square crop and local-first avatar save flow.
//

internal import SwiftUI
import PhotosUI
internal import UIKit

struct MemberAvatarEditorSheet: View {

    @EnvironmentObject private var userStore: UserStore
    @Environment(\.dismiss) private var dismiss

    let memberId: UUID
    let fallbackName: String

    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var sourceImage: UIImage?
    @State private var crop = MemberAvatarCrop()
    @State private var hasLoadedStoredAvatar = false
    @State private var isLoadingPhoto = false
    @State private var saveError: String?
    @State private var showsRemoveConfirmation = false

    init(member: User) {
        memberId = member.id
        fallbackName = member.name
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 22) {
                    avatarPreview

                    VStack(spacing: 10) {
                        PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                            Label(
                                sourceImage == nil ? "Foto auswählen" : "Anderes Foto wählen",
                                systemImage: "photo.on.rectangle.angled"
                            )
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(isLoadingPhoto)

                        if sourceImage != nil {
                            Button("Ausschnitt zurücksetzen") {
                                crop = MemberAvatarCrop()
                            }
                            .buttonStyle(.bordered)
                        }
                    }

                    if let sourceImage {
                        cropControls(image: sourceImage)
                    }

                    privacyNote

                    if showsRemoveButton {
                        Button(role: .destructive) {
                            showsRemoveConfirmation = true
                        } label: {
                            Label("Bild entfernen", systemImage: "trash")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                    }

                    if userStore.pendingCloudChangesCount > 0,
                       CloudKitRouting.normalizedGroupId(userStore.currentGroupId) != nil {
                        Label(
                            "Änderungen werden mit deiner Gruppe synchronisiert.",
                            systemImage: "arrow.triangle.2.circlepath"
                        )
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("Profilbild")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Speichern") {
                        saveAvatar()
                    }
                    .disabled(sourceImage == nil || isLoadingPhoto)
                }
            }
        }
        .task {
            loadStoredAvatarIfNeeded()
        }
        // PhotosPicker may deliberately withhold itemIdentifier. The selected item itself
        // must drive loading so a nil identifier cannot swallow the selection event.
        .task(id: selectedPhotoItem) {
            await loadSelectedPhoto()
        }
        .confirmationDialog(
            "Profilbild entfernen?",
            isPresented: $showsRemoveConfirmation,
            titleVisibility: .visible
        ) {
            Button("Bild entfernen", role: .destructive) {
                removeAvatar()
            }
            Button("Abbrechen", role: .cancel) {}
        } message: {
            Text("Bei Gruppen wird die Änderung auch für die anderen Mitglieder sichtbar.")
        }
        .alert(
            "Profilbild konnte nicht gespeichert werden",
            isPresented: Binding(
                get: { saveError != nil },
                set: { if $0 == false { saveError = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(saveError ?? "Unbekannter Fehler")
        }
    }

    @ViewBuilder
    private var avatarPreview: some View {
        if let sourceImage {
            MemberAvatarCropPreview(image: sourceImage, crop: $crop)
                .frame(height: 250)
        } else {
            MemberAvatarView(
                member: currentMember,
                fallbackName: fallbackName,
                groupId: userStore.currentGroupId,
                size: 184
            )
            .padding(.vertical, 26)
        }
    }

    private func cropControls(image: UIImage) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Ausschnitt", systemImage: "viewfinder")
                    .font(.subheadline.weight(.semibold))

                Spacer(minLength: 12)

                Text(String(format: "%.1f×", Double(crop.zoom)))
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            Slider(value: $crop.zoom, in: MemberAvatarCrop.minimumZoom...MemberAvatarCrop.maximumZoom, step: 0.1)

            Text("Ziehe das Bild, um den Ausschnitt zu wählen, und nutze den Regler für den Zoom.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .onChange(of: crop.zoom) { _, _ in
            crop = crop.clamped()
        }
    }

    private var privacyNote: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: CloudKitRouting.normalizedGroupId(userStore.currentGroupId) == nil ? "iphone" : "person.2.fill")
                .foregroundStyle(.secondary)

            Text(privacyText)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(14)
        .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var currentMember: User? {
        userStore.users.first(where: { $0.id == memberId })
    }

    private var privacyText: String {
        if CloudKitRouting.normalizedGroupId(userStore.currentGroupId) == nil {
            return "In der Standardgruppe bleibt dieses Bild ausschließlich auf diesem Gerät."
        }
        return "Dieses Bild wird mit den Mitgliedern dieser Filmgruppe synchronisiert."
    }

    private var showsRemoveButton: Bool {
        guard let currentMember else {
            return false
        }

        return currentMember.avatarVersion != nil ||
            userStore.avatarStorage.avatarData(memberId: memberId, groupId: userStore.currentGroupId) != nil
    }

    @MainActor
    private func loadStoredAvatarIfNeeded() {
        guard hasLoadedStoredAvatar == false else { return }
        hasLoadedStoredAvatar = true

        guard let data = userStore.avatarStorage.avatarData(
            memberId: memberId,
            groupId: userStore.currentGroupId
        ),
        let image = UIImage(data: data) else {
            return
        }

        sourceImage = MemberAvatarImageProcessor.normalizedImage(image)
    }

    @MainActor
    private func loadSelectedPhoto() async {
        guard let selectedPhotoItem else { return }
        isLoadingPhoto = true
        defer { isLoadingPhoto = false }

        do {
            guard let data = try await selectedPhotoItem.loadTransferable(type: Data.self),
                  let image = UIImage(data: data) else {
                saveError = "Das ausgewählte Foto konnte nicht gelesen werden."
                return
            }

            sourceImage = MemberAvatarImageProcessor.normalizedImage(image)
            crop = MemberAvatarCrop()
        } catch {
            saveError = error.localizedDescription
        }
    }

    private func saveAvatar() {
        guard let sourceImage,
              let avatarData = MemberAvatarImageProcessor.jpegData(from: sourceImage, crop: crop) else {
            saveError = "Das ausgewählte Foto konnte nicht verarbeitet werden."
            return
        }

        do {
            try userStore.updateAvatar(avatarData, forMemberId: memberId)
            dismiss()
        } catch {
            saveError = error.localizedDescription
        }
    }

    private func removeAvatar() {
        do {
            try userStore.removeAvatar(forMemberId: memberId)
            dismiss()
        } catch {
            saveError = error.localizedDescription
        }
    }
}

private struct MemberAvatarCropPreview: View {

    let image: UIImage
    @Binding var crop: MemberAvatarCrop

    @State private var dragStartCrop = MemberAvatarCrop()
    @State private var isDragging = false

    var body: some View {
        GeometryReader { proxy in
            let sideLength = min(proxy.size.width, proxy.size.height)
            let drawingRect = MemberAvatarImageProcessor.drawingRect(
                for: image.size,
                sideLength: sideLength,
                crop: crop
            )

            ZStack {
                Color.black.opacity(0.08)

                Image(uiImage: image)
                    .resizable()
                    .frame(width: drawingRect.width, height: drawingRect.height)
                    .position(x: drawingRect.midX, y: drawingRect.midY)
            }
            .frame(width: sideLength, height: sideLength)
            .clipShape(Circle())
            .overlay(
                Circle()
                    .stroke(Color.white.opacity(0.9), lineWidth: 3)
            )
            .shadow(color: .black.opacity(0.16), radius: 16, y: 8)
            .contentShape(Circle())
            .gesture(dragGesture(sideLength: sideLength))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .aspectRatio(1, contentMode: .fit)
    }

    private func dragGesture(sideLength: CGFloat) -> some Gesture {
        DragGesture()
            .onChanged { value in
                if isDragging == false {
                    dragStartCrop = crop
                    isDragging = true
                }
                crop = cropAfterDragging(value.translation, sideLength: sideLength)
            }
            .onEnded { _ in
                isDragging = false
            }
    }

    private func cropAfterDragging(_ translation: CGSize, sideLength: CGFloat) -> MemberAvatarCrop {
        let drawnSize = MemberAvatarImageProcessor.drawnSize(
            for: image.size,
            sideLength: sideLength,
            crop: dragStartCrop
        )
        let maximumHorizontalOffset = max((drawnSize.width - sideLength) / 2, 0)
        let maximumVerticalOffset = max((drawnSize.height - sideLength) / 2, 0)

        var next = dragStartCrop
        if maximumHorizontalOffset > 0 {
            next.horizontalPosition += translation.width / maximumHorizontalOffset
        } else {
            next.horizontalPosition = 0
        }

        if maximumVerticalOffset > 0 {
            next.verticalPosition += translation.height / maximumVerticalOffset
        } else {
            next.verticalPosition = 0
        }

        return next.clamped()
    }
}

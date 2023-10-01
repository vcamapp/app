//
//  SceneObject+.swift
//  
//
//  Created by Tatsuya Tanaka on 2022/05/05.
//

import Foundation
import VCamEntity

extension VCamScene.Object {
    public func sceneObject(dataStore: VCamSceneDataStore) -> SceneObject {
        switch type {
        case let .avatar(avatar):
            return sceneObject(type: .avatar(.init(
                position: avatar.position.simd3,
                rotation: avatar.rotation.simd3
            )))
        case let .image(id, image):
            let url = dataStore.dataURL(id: id)
            return sceneObject(type: .image(.init(
                url: url,
                offset: .init(image.x, image.y),
                size: .init(width: CGFloat(image.width), height: CGFloat(image.height)),
                filter: image.filter.map(ImageFilter.init(configuration:))
            )))
        case let .screen(id, state):
            let texture = state.texture
            return sceneObject(type: .screen(.init(
                id: id,
                captureType: state.captureType,
                textureSize: texture.textureSize,
                region: texture.region.rect,
                crop: texture.crop.rect,
                filter: state.texture.filter.map(ImageFilter.init(configuration:))
            )))
        case let .captureDevice(uniqueID, state):
            return sceneObject(type: .videoCapture(.init(
                id: uniqueID, 
                textureSize: state.textureSize,
                region: state.region.rect,
                crop: state.crop.rect,
                filter: state.filter.map(ImageFilter.init(configuration:))
            )))
        case let .web(state):
            let texture = state.texture
            return sceneObject(type: .web(.init(
                url: state.url,
                path: state.path,
                fps: state.fps,
                css: state.css,
                js: state.js,
                textureSize: texture.textureSize,
                region: texture.region.rect,
                crop: texture.crop.rect,
                filter: texture.filter.map(ImageFilter.init(configuration:))
            )))
        case let .wind(wind):
            return sceneObject(type: .wind(.init(direction: wind.rotation.simd3)))
        }
    }

    private func sceneObject(type: SceneObject.ObjectType) -> SceneObject {
        .init(id: id, type: type, name: name, isHidden: isHidden ?? false, isLocked: isLocked ?? false)
    }
}

extension SceneObject {
    func encodeScene() throws -> VCamScene.Object {
        switch type {
        case let .avatar(avatar):
            return encodeScene(type: .avatar(state: .init(
                position: .init(vector: avatar.position),
                rotation: .init(vector: avatar.rotation)
            )))
        case let .image(image):
            let id = try VCamSceneDataStore.dataId(fromURL: image.url)
            return encodeScene(type: .image(id: id.uuidString, state: .init(
                x: image.offset.x,
                y: image.offset.y,
                width: Float(image.size.width),
                height: Float(image.size.height),
                filter: image.filter?.configuration
            )))
        case let .screen(screen):
            return encodeScene(type: .screen(id: screen.id , state: .init(
                captureType: screen.captureType, 
                texture: .init(
                    width: Float(screen.textureSize.width),
                    height: Float(screen.textureSize.height),
                    region: .init(rect: screen.region),
                    crop: .init(rect: screen.crop),
                    filter: screen.filter?.configuration
                ))
            ))
        case let .videoCapture(videoCapture):
            return encodeScene(type: .captureDevice(id: videoCapture.id, state: .init(
                width: Float(videoCapture.textureSize.width),
                height: Float(videoCapture.textureSize.height),
                region: .init(rect: videoCapture.region),
                crop: .init(rect: videoCapture.crop),
                filter: videoCapture.filter?.configuration
            )))
        case let .web(web):
            return encodeScene(type: .web(state: .init(
                url: web.url,
                path: web.path,
                fps: web.fps,
                css: web.css,
                js: web.js,
                texture: .init(
                    width: Float(web.textureSize.width),
                    height: Float(web.textureSize.height),
                    region: .init(rect: web.region),
                    crop: .init(rect: web.crop),
                    filter: web.filter?.configuration
                )
            )))
        case let .wind(wind):
            return encodeScene(type: .wind(state: .init(
                position: .zero,
                rotation: .init(vector: wind.direction)
            )))
        }
    }

    private func encodeScene(type: VCamScene.ObjectType) -> VCamScene.Object {
        .init(id: id, name: name, type: type, isHidden: isHidden, isLocked: isLocked)
    }
}

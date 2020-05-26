//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift Distributed Actors open source project
//
// Copyright (c) 2019-2020 Apple Inc. and the Swift Distributed Actors project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.md for the list of Swift Distributed Actors project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

@testable import DistributedActors
import DistributedActorsTestKit
import XCTest

final class CRDTReplicationSerializationTests: ActorSystemTestBase {
    override func setUp() {
        _ = self.setUpNode(String(describing: type(of: self))) { settings in
            // TODO: all this registering will go away with _mangledTypeName
            settings.serialization.register(CRDT.ORSet<String>.self, serializerID: Serialization.ReservedID.CRDTORSet)
            settings.serialization.register(CRDT.ORSet<String>.Delta.self, serializerID: Serialization.ReservedID.CRDTORSetDelta)
        }
    }

    let ownerAlpha = try! ActorAddress(path: ActorPath._user.appending("alpha"), incarnation: .wellKnown)
    let ownerBeta = try! ActorAddress(path: ActorPath._user.appending("beta"), incarnation: .wellKnown)

    typealias WriteResult = CRDT.Replicator.RemoteCommand.WriteResult
    typealias ReadResult = CRDT.Replicator.RemoteCommand.ReadResult
    typealias DeleteResult = CRDT.Replicator.RemoteCommand.DeleteResult

    // ==== ------------------------------------------------------------------------------------------------------------
    // MARK: CRDT.Replicator.RemoteCommand.write and .writeDelta

    func test_serializationOf_RemoteCommand_write_GCounter() throws {
        try shouldNotThrow {
            let id = CRDT.Identity("gcounter-1")
            var g1 = CRDT.GCounter(replicaID: .actorAddress(self.ownerAlpha))
            g1.increment(by: 5)
            g1.delta.shouldNotBeNil()

            let resultProbe = self.testKit.spawnTestProbe(expecting: CRDT.Replicator.RemoteCommand.WriteResult.self)
            let write: CRDT.Replicator.Message = .remoteCommand(.write(id, g1, replyTo: resultProbe.ref))

            let serialized = try system.serialization.serialize(write)
            let deserialized = try system.serialization.deserialize(as: CRDT.Replicator.Message.self, from: serialized)

            guard case .remoteCommand(.write(let deserializedId, let deserializedData, let deserializedReplyTo)) = deserialized else {
                throw self.testKit.fail("Should be RemoteCommand.write message")
            }
            deserializedId.shouldEqual(id)
            deserializedReplyTo.shouldEqual(resultProbe.ref)

            guard let dg1 = deserializedData as? CRDT.GCounter else {
                throw self.testKit.fail("Should be a GCounter")
            }
            dg1.value.shouldEqual(g1.value)
            dg1.delta.shouldNotBeNil()
        }
    }

    func test_serializationOf_RemoteCommand_write_ORSet() throws {
        try shouldNotThrow {
            let id = CRDT.Identity("set-1")
            var set = CRDT.ORSet<String>(replicaID: .actorAddress(self.ownerAlpha))
            set.insert("hello")
            set.insert("world")
            set.delta.shouldNotBeNil()

            let resultProbe = self.testKit.spawnTestProbe(expecting: CRDT.Replicator.RemoteCommand.WriteResult.self)
            let write: CRDT.Replicator.Message = .remoteCommand(.write(id, set, replyTo: resultProbe.ref))

            let serialized = try system.serialization.serialize(write)
            let deserialized = try system.serialization.deserialize(as: CRDT.Replicator.Message.self, from: serialized)

            guard case .remoteCommand(.write(let deserializedId, let deserializedData, let deserializedReplyTo)) = deserialized else {
                throw self.testKit.fail("Should be RemoteCommand.write message")
            }
            deserializedId.shouldEqual(id)
            deserializedReplyTo.shouldEqual(resultProbe.ref)

            guard let dset = deserializedData as? CRDT.ORSet<String> else {
                throw self.testKit.fail("Should be a ORSet<String>")
            }
            dset.elements.shouldEqual(set.elements)
            dset.delta.shouldNotBeNil()
        }
    }

    func test_serializationOf_RemoteCommand_writeDelta_GCounter() throws {
        try shouldNotThrow {
            let id = CRDT.Identity("gcounter-1")
            var g1 = CRDT.GCounter(replicaID: .actorAddress(self.ownerAlpha))
            g1.increment(by: 5)
            g1.delta.shouldNotBeNil()

            let resultProbe = self.testKit.spawnTestProbe(expecting: WriteResult.self)
            let write: CRDT.Replicator.Message = .remoteCommand(.writeDelta(id, delta: g1.delta!, replyTo: resultProbe.ref)) // !-safe since we check for nil above

            let serialized = try system.serialization.serialize(write)
            let deserialized = try system.serialization.deserialize(as: CRDT.Replicator.Message.self, from: serialized)

            guard case .remoteCommand(.writeDelta(let deserializedId, let deserializedDelta, let deserializedReplyTo)) = deserialized else {
                throw self.testKit.fail("Should be RemoteCommand.write message")
            }
            deserializedId.shouldEqual(id)
            deserializedReplyTo.shouldEqual(resultProbe.ref)

            guard let ddg1 = deserializedDelta as? CRDT.GCounterDelta else {
                throw self.testKit.fail("Should be a GCounter")
            }
            "\(ddg1.state)".shouldContain("[actor:sact://CRDTReplicationSerializationTests@127.0.0.1:9001/user/alpha: 5]")
        }
    }

    func test_serializationOf_RemoteCommand_WriteResult_success() throws {
        try shouldNotThrow {
            let result = WriteResult.success

            let serialized = try system.serialization.serialize(result)
            let deserialized = try system.serialization.deserialize(as: WriteResult.self, from: serialized)

            guard case .success = deserialized else {
                throw self.testKit.fail("Should be RemoteCommand.WriteResult.success message")
            }
        }
    }

    func test_serializationOf_RemoteCommand_WriteResult_failed() throws {
        try shouldNotThrow {
            let hint = "should be this other type"
            let result = WriteResult.failure(.inputAndStoredDataTypeMismatch(hint: hint))

            let serialized = try system.serialization.serialize(result)
            let deserialized = try system.serialization.deserialize(as: WriteResult.self, from: serialized)

            guard case .failure(.inputAndStoredDataTypeMismatch(let deserializedHint)) = deserialized else {
                throw self.testKit.fail("Should be RemoteCommand.WriteResult.failure message with .inputAndStoredDataTypeMismatch error")
            }
            deserializedHint.shouldEqual(hint)
        }
    }

    // ==== ------------------------------------------------------------------------------------------------------------
    // MARK: CRDT.Replicator.RemoteCommand.read

    func test_serializationOf_RemoteCommand_read() throws {
        try shouldNotThrow {
            let id = CRDT.Identity("gcounter-1")

            let resultProbe = self.testKit.spawnTestProbe(expecting: ReadResult.self)
            let read: CRDT.Replicator.Message = .remoteCommand(.read(id, replyTo: resultProbe.ref))

            let serialized = try system.serialization.serialize(read)
            let deserialized = try system.serialization.deserialize(as: CRDT.Replicator.Message.self, from: serialized)

            guard case .remoteCommand(.read(let deserializedId, let deserializedReplyTo)) = deserialized else {
                throw self.testKit.fail("Should be RemoteCommand.read message")
            }
            deserializedId.shouldEqual(id)
            deserializedReplyTo.shouldEqual(resultProbe.ref)
        }
    }

    func test_serializationOf_RemoteCommand_ReadResult_success() throws {
        try shouldNotThrow {
            var g1 = CRDT.GCounter(replicaID: .actorAddress(self.ownerAlpha))
            g1.increment(by: 5)
            g1.delta.shouldNotBeNil()

            let result = ReadResult.success(g1)

            let serialized = try system.serialization.serialize(result)
            let deserialized = try system.serialization.deserialize(as: ReadResult.self, from: serialized)

            guard case .success(let deserializedData) = deserialized else {
                throw self.testKit.fail("Should be RemoteCommand.ReadResult.success message")
            }
            guard let dg1 = deserializedData as? CRDT.GCounter else {
                throw self.testKit.fail("Should be a GCounter")
            }
            dg1.value.shouldEqual(g1.value)
            dg1.delta.shouldNotBeNil()
        }
    }

    func test_serializationOf_RemoteCommand_ReadResult_failed() throws {
        try shouldNotThrow {
            let result = ReadResult.failure(.notFound)

            let serialized = try system.serialization.serialize(result)
            let deserialized = try system.serialization.deserialize(as: ReadResult.self, from: serialized)

            guard case .failure(.notFound) = deserialized else {
                throw self.testKit.fail("Should be RemoteCommand.ReadResult.failure message with .notFound error")
            }
        }
    }

    // ==== ------------------------------------------------------------------------------------------------------------
    // MARK: CRDT.Replicator.RemoteCommand.delete

    func test_serializationOf_RemoteCommand_delete() throws {
        try shouldNotThrow {
            let id = CRDT.Identity("gcounter-1")

            let resultProbe = self.testKit.spawnTestProbe(expecting: DeleteResult.self)
            let delete: CRDT.Replicator.Message = .remoteCommand(.delete(id, replyTo: resultProbe.ref))

            let serialized = try system.serialization.serialize(delete)
            let deserialized = try system.serialization.deserialize(as: CRDT.Replicator.Message.self, from: serialized)

            guard case .remoteCommand(.delete(let deserializedId, let deserializedReplyTo)) = deserialized else {
                throw self.testKit.fail("Should be RemoteCommand.delete message")
            }
            deserializedId.shouldEqual(id)
            deserializedReplyTo.shouldEqual(resultProbe.ref)
        }
    }

    func test_serializationOf_RemoteCommand_DeleteResult_success() throws {
        try shouldNotThrow {
            let result = DeleteResult.success

            let serialized = try system.serialization.serialize(result)
            let deserialized = try system.serialization.deserialize(as: DeleteResult.self, from: serialized)

            guard case .success = deserialized else {
                throw self.testKit.fail("Should be RemoteCommand.DeleteResult.success message")
            }
        }
    }
}

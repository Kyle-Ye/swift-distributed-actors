//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift Distributed Actors open source project
//
// Copyright (c) 2020 Apple Inc. and the Swift Distributed Actors project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.md for the list of Swift Distributed Actors project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

@testable import DistributedActors
import Logging
import NIO

// usual reminder that Swift Distributed Actors is not inherently "client/server" once associated, only the handshake is
enum HandshakeSide: String {
    case client
    case server
}

extension ClusterShellState {
    static func makeTestMock(side: HandshakeSide, configureSettings: (inout ClusterSettings) -> Void = { _ in () }) -> ClusterShellState {
        var settings = ClusterSettings(
            node: Node(
                systemName: "MockSystem",
                host: "127.0.0.1",
                port: 7337
            )
        )
        configureSettings(&settings)
        let log = Logger(label: "handshake-\(side)") // TODO: could be a mock logger we can assert on?

        return ClusterShellState(
            settings: settings,
            channel: EmbeddedChannel(),
            events: EventStream(ref: ActorRef(.deadLetters(.init(log, address: ._deadLetters, system: nil)))),
            gossipControl: ConvergentGossipControl(ActorRef(.deadLetters(.init(log, address: ._deadLetters, system: nil)))),
            log: log
        )
    }
}

// ==== ----------------------------------------------------------------------------------------------------------------
// MARK: Membership Testing DSL

extension Cluster.Gossip {
    /// First line is Membership DSL, followed by lines of the SeenTable DSL
    internal static func parse(_ dsl: String, owner: UniqueNode, nodes: [UniqueNode]) -> Cluster.Gossip {
        let dslLines = dsl.split(separator: "\n")
        var gossip = Cluster.Gossip(ownerNode: owner)
        gossip.membership = Cluster.Membership.parse(String(dslLines.first!), nodes: nodes)
        gossip.seen = Cluster.Gossip.SeenTable.parse(dslLines.dropFirst().joined(separator: "\n"), nodes: nodes)
        return gossip
    }
}

extension Cluster.Gossip.SeenTable {
    /// Express seen tables using a DSL
    /// Syntax: each line: `<owner>: <node>@<version>*`
    internal static func parse(_ dslString: String, nodes: [UniqueNode], file: StaticString = #file, line: UInt = #line) -> Cluster.Gossip.SeenTable {
        let lines = dslString.split(separator: "\n")
        func nodeById(id: String.SubSequence) -> UniqueNode {
            if let found = nodes.first(where: { $0.node.systemName.contains(id) }) {
                return found
            } else {
                fatalError("Could not find node containing [\(id)] in \(nodes), for seen table: \(dslString)", file: file, line: line)
            }
        }

        var table = Cluster.Gossip.SeenTable()

        for line in lines {
            let elements = line.split(separator: " ")
            let id = elements.first!.dropLast(1)
            let on = nodeById(id: id)

            var vv = VersionVector.empty
            for dslVersion in elements.dropFirst() {
                let parts = dslVersion.split { c in "@:".contains(c) }

                let atId = parts.first!
                let atNode = nodeById(id: atId)

                let versionString = parts.dropFirst().first!
                let atVersion = Int(versionString)!

                vv.state[.uniqueNode(atNode)] = atVersion
            }

            table.underlying[on] = vv
        }

        return table
    }
}

extension VersionVector {
    internal static func parse(_ dslString: String, nodes: [UniqueNode], file: StaticString = #file, line: UInt = #line) -> VersionVector {
        func nodeById(id: String.SubSequence) -> UniqueNode {
            if let found = nodes.first(where: { $0.node.systemName.contains(id) }) {
                return found
            } else {
                fatalError("Could not find node containing [\(id)] in \(nodes), for seen table: \(dslString)", file: file, line: line)
            }
        }

        let replicaVersions: [VersionVector.ReplicaVersion] = dslString.split(separator: " ").map { segment in
            let v = segment.split { c in ":@".contains(c) }
            return (.uniqueNode(nodeById(id: v.first!)), Int(v.dropFirst().first!)!)
        }
        return VersionVector(replicaVersions)
    }
}

extension Cluster.Membership {
    /// Express membership as: `F.up S.down T.joining`.
    ///
    /// Syntax reference:
    ///
    /// ```
    /// <node identifier>[.:]<node status> || [leader:<node identifier>]
    /// ```
    internal static func parse(_ dslString: String, nodes: [UniqueNode], file: StaticString = #file, line: UInt = #line) -> Cluster.Membership {
        func nodeById(id: String.SubSequence) -> UniqueNode {
            if let found = nodes.first(where: { $0.node.systemName.contains(id) }) {
                return found
            } else {
                fatalError("Could not find node containing [\(id)] in \(nodes), for seen table: \(dslString)", file: file, line: line)
            }
        }

        var membership = Cluster.Membership.empty

        for nodeDsl in dslString.split(separator: " ") {
            let elements = nodeDsl.split { c in ".:".contains(c) }
            let nodeId = elements.first!
            if nodeId == "[leader" {
                // this is hacky, but good enough for our testing tools
                let actualNodeId = elements.dropFirst().first!
                let leaderNode = nodeById(id: actualNodeId.dropLast(1))
                let leaderMember = membership.uniqueMember(leaderNode)!
                membership.leader = leaderMember
            } else {
                let node = nodeById(id: nodeId)

                let statusString = String(elements.dropFirst().first!)
                let status = Cluster.MemberStatus.parse(statusString)!

                _ = membership.join(node)
                _ = membership.mark(node, as: status)
            }
        }

        return membership
    }
}

extension Cluster.MemberStatus {
    /// Not efficient but useful for constructing mini DSLs to write membership
    internal static func parse(_ s: String) -> Cluster.MemberStatus? {
        let id = String(s.trimmingCharacters(in: .symbols))
        for c in Self.allCases where id == "\(c)" {
            return c
        }

        return nil
    }
}

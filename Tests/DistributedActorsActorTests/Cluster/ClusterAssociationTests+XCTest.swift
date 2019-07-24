//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift Distributed Actors open source project
//
// Copyright (c) 2018-2019 Apple Inc. and the Swift Distributed Actors project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.md for the list of Swift Distributed Actors project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import XCTest

///
/// NOTE: This file was generated by generate_linux_tests.rb
///
/// Do NOT edit this file directly as it will be regenerated automatically when needed.
///

extension ClusterAssociationTests {

   static var allTests : [(String, (ClusterAssociationTests) -> () throws -> Void)] {
      return [
                ("test_boundServer_shouldAcceptAssociate", test_boundServer_shouldAcceptAssociate),
                ("test_handshake_shouldNotifyOnSuccess", test_handshake_shouldNotifyOnSuccess),
                ("test_handshake_shouldNotifySuccessWhenAlreadyConnected", test_handshake_shouldNotifySuccessWhenAlreadyConnected),
                ("test_association_sameAddressNodeJoin_shouldOverrideExistingNode", test_association_sameAddressNodeJoin_shouldOverrideExistingNode),
                ("test_association_shouldAllowSendingToRemoteReference", test_association_shouldAllowSendingToRemoteReference),
                ("test_association_shouldEstablishSingleAssociationForConcurrentlyInitiatedHandshakes_incoming_outgoing", test_association_shouldEstablishSingleAssociationForConcurrentlyInitiatedHandshakes_incoming_outgoing),
                ("test_association_shouldEstablishSingleAssociationForConcurrentlyInitiatedHandshakes_outgoing_outgoing", test_association_shouldEstablishSingleAssociationForConcurrentlyInitiatedHandshakes_outgoing_outgoing),
                ("test_association_shouldKeepTryingUntilOtherNodeBindsPort", test_association_shouldKeepTryingUntilOtherNodeBindsPort),
                ("test_association_shouldNotAssociateWhenRejected", test_association_shouldNotAssociateWhenRejected),
                ("test_handshake_shouldNotifyOnRejection", test_handshake_shouldNotifyOnRejection),
           ]
   }
}


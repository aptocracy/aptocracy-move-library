# Aptocracy Move Library

Aptocracy Move Library (AML) is a collection of modules which represent core building blocks  for creating and managing on-chain organizations on Aptos blockchain.

AML modules have support for basically any type of organization with whichever hierarchy and/or governance structure.

Currently AML consists of:
- Organization module
- Treasury module
- Proposals module
- Aptocracy module (example of usage)

## Organization module
This module defines core concepts in the Aptocracy framework which are related to the organization, its governance structure, members, roles and permissions.

Core concepts defined in this module:
- Organization
- Member
- Governance
- RoleConfig

Organization is the base concept which is used to represent the on-chain organization through  information such as name, organization type, available roles and similar. The set of data for the organization can easily be extended by utilizing the OrganizationMetadata field in the Organization struct.

Member is a representation of a user in an Organization and it contains information about the Role which member has in it. This struct is also extendable through MemberMetadata. The list of all members is maintained in Members struct.

Governance concept defines rules for making decisions inside an Organization. It contains information about the needed quorum and approval quorum, as well as the time for which the voting will last. This basic set of rules can be extended through GovernanceMetadata. Each Organization can have multiple Governances which can be used for different actions in the Organization.

RoleConfig represents the configuration for a Role in the Organization. AML supports fully customizable roles and is not limited to roles defined upfront. Actually, there are no upfront defined roles in the Organization module and developers have flexibility to build and define the roles and action which suit their needs the best. RoleConfig contains the information about the voting power (weight) of a Role, as well as the set of Actions that the Role is eligible to take. There are some Actions that are already defined in the Organization module and which are needed for its functioning, but it is on the developer to define the desired Actions per his needs.

Organization modules implements following instructions:
- `create_organization`
- `create_governance`
- `invite_member`
- `accept_membership`
- `update_main_governance`
- `change_governance_config`
- `join_organization`

## Treasury module
This module defines concepts in the Aptocracy framework which are related to the treasury, member deposits and assets that can be under the Organization management. Even though it is developed for the purpose of using it together with the Organization module, it is important to emphasize that the Treasury module is built in such a way that it can be utilized independently.

Core concepts defined in this module:

- Treasury
- DepositRecord

Treasury is the base concept which is used to represent the specific Treasury instance with the  type of the coin it stores and total deposited amount. It can also be extended through the TreasuryMetadata.

DepositRecord represents a record which contains information about one specific Deposit or Withdrawal action done on the Treasury. It contains a list of DepositItems and WithdrawalItems.

Treasury module implements following instructions:

- `create_treasury`
- `deposit`
- `withdraw`
- `transfer_funds`

## Proposals module

Core concepts defined in this module:

- Proposal
- VoteThreshold
- VoteOption
- ExecutionStep
- Vote
- VotingRecords

Proposals module implements following instructions:

- `initialize`
- `create_proposal`
- `vote_for_proposal`
- `cancel_proposal`
- `finalize_votes`
- `relinquish_vote`
- `execute_proposal_option`

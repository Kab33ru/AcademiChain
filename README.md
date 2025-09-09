# AcademiChain

A decentralized academic credential verification and validation platform built on the Stacks blockchain. AcademiChain enables institutions to issue, verify, and rate academic credentials while earning tokens based on verification activities and quality assessments.

## Features

- **Institution Registration**: Universities, validators, and employers can register and manage their profiles
- **Credential Issuance**: Academic institutions can issue verifiable credentials with cryptographic hashes
- **Peer Validation**: Multiple institutions can validate credentials to establish authenticity
- **Quality Rating System**: Community-driven rating system for credential quality assessment
- **Token Rewards**: Institutions earn tokens for validation activities and high-quality credentials
- **Reputation System**: Build institutional reputation through consistent validation and quality work

## Smart Contract Functions

### Institution Management
- `register-institution`: Register as a university, validator, or employer
- `update-institution`: Update institution profile information

### Credential Operations
- `issue-credential`: Submit new academic credentials for validation
- `validate-credential`: Validate credentials issued by other institutions
- `endorse-credential`: Endorse verified credentials from employers/industry
- `rate-credential-quality`: Rate the quality and rigor of academic credentials

### Read-Only Functions
- `get-institution-info`: Retrieve institution profile and statistics
- `get-credential`: Get detailed credential information
- `get-total-credentials`: Get total number of credentials in the system

## Getting Started

1. Deploy the contract to Stacks blockchain
2. Register your institution using `register-institution`
3. Start issuing credentials or validating existing ones
4. Participate in the quality rating system to earn tokens and build reputation

## Token Economics

- **Validation Reward**: 5 tokens per credential validation
- **Accreditation Reward**: 50 tokens when credential reaches verified status
- **Excellence Reward**: 20 tokens for high-quality credential ratings
- **Rating Participation**: 2 tokens per quality rating submitted

## Requirements

- Stacks blockchain connection
- Clarinet for local development and testing
- Valid institution registration to participate

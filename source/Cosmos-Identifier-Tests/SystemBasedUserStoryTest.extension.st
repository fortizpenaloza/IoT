Extension { #name : #SystemBasedUserStoryTest }

{ #category : #'*Cosmos-Identifier-Tests' }
SystemBasedUserStoryTest >> currentIdentifier [

	^ 1
]

{ #category : #'*Cosmos-Identifier-Tests' }
SystemBasedUserStoryTest >> identifierProvider [

	^ FixedNumberProvider providing: self currentIdentifier
]

{ #category : #'*Cosmos-Identifier-Tests' }
SystemBasedUserStoryTest >> identifierSystem [

	^ rootSystem systemImplementing: #IdentifierSystemInterface
]

{ #category : #'*Cosmos-Identifier-Tests' }
SystemBasedUserStoryTest >> requireIdentifierSystem [

	systemBuilder add: (IdentifierSystem using: self identifierProvider)
]
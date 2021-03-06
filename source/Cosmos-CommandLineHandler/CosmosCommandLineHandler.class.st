"
Usage: printVersion [ --port | --debug-mode ]
	--port Port number for http server
	--debug-mode Http server should be installed in debug mode
	
Documentation:
Prints the version number in an easy to parse format. This can be used in Jenkins with the ""Description Setter"" Plugin. Configure it like this:

Regular expression:  \[version\] (.*)
Description: \1


Examples:
	pharo Pharo.image printVersion
	#result will be something like:
	[version] 3.0 #30100

	pharo Pharo.image printVersion --numeric
	# will print a simpler version
	30100
	
	pharo Pharo.image printVersion --release
	# prints the Pharo release version
	3.0
"
Class {
	#name : #CosmosCommandLineHandler,
	#superclass : #LaunchpadCommandLineHandler,
	#instVars : [
		'cosmos',
		'pendingActionsQueue',
		'actionEvaluationsQueue'
	],
	#category : #'Cosmos-CommandLineHandler'
}

{ #category : #accessing }
CosmosCommandLineHandler class >> commandName [

	^ 'cosmos'
]

{ #category : #accessing }
CosmosCommandLineHandler class >> description [

	^ 'Cosmos command line handler'
]

{ #category : #'private - accessing' }
CosmosCommandLineHandler class >> logPrefix [

	^ 'cosmos'
]

{ #category : #'private - accessing' }
CosmosCommandLineHandler >> allowedOrigins [

	^ self configuration at: 'allowed-origins'
]

{ #category : #'private - accessing' }
CosmosCommandLineHandler >> baseUrl [

	^ ('http://' , self hostname) asUrl port: self port
]

{ #category : #activation }
CosmosCommandLineHandler >> basicActivate [

	self
		logAsInfo: 'Creating pending evaluation actions queue'
			during: [ pendingActionsQueue := AtomicSharedQueue new ];
		logAsInfo: 'Creating action evaluation queue'
			during: [ actionEvaluationsQueue := AtomicSharedQueue new ];
		logAsInfo: 'Building and starting cosmos' 
			during: [ self buildAndStartCosmos ];
		logAsInfo: 'Building and starting RESTful API' 
			during: [ self buildAndStartCosmosAPI ];
		logAsInfo: 'Building and starting the periodical scheduler'
			during: [ self buildAndStartScheduler ];
		logAsInfo: 'Building and starting the action evaluator'
			during: [ self buildAndStartActionEvaluator ]
]

{ #category : #activation }
CosmosCommandLineHandler >> buildAndStartActionEvaluator [

	| evaluator |

	evaluator := ActionEvaluator
		evaluatingActionsFrom: pendingActionsQueue
		using: (ActionEvaluatorConfiguration workingWith: SystemTimeSource new)
		registeringEvaluationsInto: actionEvaluationsQueue.

	evaluator start
	

]

{ #category : #'private - building cosmos system' }
CosmosCommandLineHandler >> buildAndStartCosmos [

	cosmos := CompositeSystem new.

	cosmos
		register: (TimeSystem using: SystemTimeSource new);
		register: EventNotificationSystem new;
		register: MetadataSystem new;
		register: (IdentifierSystem using: UUIDProvider new);
		register: TimestampingSystem new;
		register: DataStreamManagementSystem new;
		register: (TriggerManagementSystem enqueuingActionsInto: pendingActionsQueue);
		register: ActionManagementSystem new;
		register: (ActionEvaluationSystem registeringFrom: actionEvaluationsQueue);
		register: CommandManagementSystem new.
		
	cosmos startUp
]

{ #category : #'private - building cosmos API' }
CosmosCommandLineHandler >> buildAndStartCosmosAPI [

	| api |

	api := HTTPBasedRESTfulAPI
		configuredBy:
			{(#port -> self port).
			(#debugMode -> self isDebugModeEnabled).
			(#serverUrl -> self baseUrl)}
		installing:
			{(DataStreamsRESTfulController workingWith: cosmos).
			(DataPointsRESTfulController workingWith: cosmos).
			(CommandsRESTfulController workingWith: cosmos).
			(ActionsRESTfulController workingWith: cosmos).
			(ActionEvaluationsRESTfulController workingWith: cosmos).
			(TriggersRESTfulController workingWith: cosmos)}..
			
	api
		on: self exceptionsToHandle
		addErrorHandler: [ :signal :request | self class dumpStackAndReport: signal ].
		
	api beCORSAwareAllowing: self allowedOrigins.

	api
		install;
		start
]

{ #category : #'private - building scheduler' }
CosmosCommandLineHandler >> buildAndStartScheduler [

	| scheduler  |

	scheduler := self periodicalScheduler.
	
	self timePeriodsToSchedule
		do: [ :timePeriod | | task |

			task := Task
				named: ('Notify every <1p>' expandMacrosWith: timePeriod)
				do: [ (cosmos systemImplementing: #EventNotificationSystemInterface)
						notifySubscribersTo: (TickEvent of: timePeriod) ].

			scheduler schedule: task toBeExecutedEvery: timePeriod ].
		
	scheduler start
]

{ #category : #'private - accessing' }
CosmosCommandLineHandler >> configurationDefinition [

	^ OrderedCollection new
		add: (OptionalArgument named: 'hostname' defaultingTo: 'localhost');
		add: (OptionalArgument named: 'port' defaultingTo: 57001 convertingWith: #asNumber);
		add:
			(MandatoryArgument
				named: 'allowed-origins'
				convertingWith: [ :string | ((string substrings: ',') collect: #trim) collect: #asUrl ]);
		asArray
]

{ #category : #'private - accessing' }
CosmosCommandLineHandler >> hostname [

	^ self configuration at: 'hostname'
]

{ #category : #logging }
CosmosCommandLineHandler >> logAsInfo: aMessage during: aBlock [

	CurrentLogger value logAsInfo: aMessage during: aBlock
]

{ #category : #'private - accessing' }
CosmosCommandLineHandler >> port [

	^ self configuration at: 'port'
]

{ #category : #'private - accessing' }
CosmosCommandLineHandler >> timePeriodsToSchedule [

	^ {(TimeUnits second with: 10).
	(TimeUnits minute with: 1).
	(TimeUnits minute with: 10).
	(TimeUnits hour with: 1)}
]

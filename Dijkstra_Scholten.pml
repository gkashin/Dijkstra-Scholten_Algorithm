// Number of nodes
#define N 4
// Length of channels
#define L 10

int inDeficitArray[N * N] = 0;
int inDeficit[N] = 0;
int outDeficit[N] = 0;
int parent[N] = -1;

// Property indicating whether the node is terminated (true in our case)
bool isTerminated[N] = true;
bool systemTerminated = false;

mtype = { signal, message };
chan ch[N] = [L] of { mtype, byte };

int messagesSent = 0;
int signalsSent = 0;

int count = 0;
int maxMessagesCount = 10000000;

proctype environmentNode(byte myID) {
	byte dst;

	/* Send message */
	for (dst : 1 .. N - 1) {
		ch[dst] ! message, myID;
		messagesSent++;
		outDeficit[myID]++;
	}

	/* Receive signal */
	do 
	:: 	ch[myID] ? signal, _;
		signalsSent--;
		outDeficit[myID]--;

		if
		:: outDeficit[myID] == 0 -> systemTerminated = true;
		:: else -> skip;
		fi
	od
}

proctype node(byte myID) {
	byte dst;

	do
	/* Send message */ 
	::
		// Choose destination node indeterminately
		if
		:: dst = 1;
		:: dst = 2;
		:: dst = 3;
		fi;

		if 
		:: (parent[myID] != -1 && dst != myID && dst != 0 && count < maxMessagesCount) ->
			ch[dst] ! message, myID;
			messagesSent++;
			outDeficit[myID]++;
		:: else -> skip;
		fi;
		
		if 
		:: count < maxMessagesCount -> count++;
		:: else -> skip;
		fi;

	/* Receive message */
	:: messagesSent != 0 ->
		byte src;
		ch[myID] ? message, src;
		messagesSent--;

		if
		:: parent[myID] == -1 -> parent[myID] = src; 
		:: else -> skip;
		fi;

		inDeficitArray[myID * N + src]++;
		inDeficit[myID]++;

	/* Send signal */
	::
		if
		:: inDeficit[myID] > 1 ->
			byte E;
			for (E : 0 .. N - 1) {
				if
				:: ((inDeficitArray[myID * N + E] > 1) || (inDeficitArray[myID * N + E] == 1 && parent[myID] != E)) && (E != myID) && (parent[myID] != -1) ->
					ch[E] ! signal, myID;
					signalsSent++;
					inDeficitArray[myID * N + E]--;
					inDeficit[myID]--;
					break;
				:: else -> skip;
				fi;
			}
		:: (inDeficit[myID] == 1) && isTerminated[myID] && (outDeficit[myID] == 0) && (parent[myID] != -1) -> 
			ch[parent[myID]] ! signal, myID;
			signalsSent++;
			inDeficitArray[myID * N + parent[myID]] = 0;
			inDeficit[myID] = 0;
			parent[myID] = -1;
		:: else -> skip; 
		fi

	/* Receive signal */
	:: signalsSent != 0 -> 
		ch[myID] ? signal, _;
		signalsSent--
		outDeficit[myID]--;
	od
}

init {
	byte nodeID;

	atomic {
		run environmentNode(0);
		for (nodeID : 1 .. N - 1) {
			run node(nodeID);
		}
	}
}


#define terminationAnnounced (outDeficit[0] == 0)
#define areNodesTerminated (outDeficit[1] == 0 && outDeficit[2] == 0 && outDeficit[3] == 0)

/* Liveness Property */
ltl p_liveness {[] (areNodesTerminated -> <> terminationAnnounced)}

/* Safety Property */
ltl p_safety {[] (terminationAnnounced -> areNodesTerminated)}

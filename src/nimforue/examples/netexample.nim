include unrealprelude

uClass AReplicatedActor of AActor:
  uprops(EditAnywhere, BlueprintReadWrite, ReplicatedUsing=onRepReplicatedVar):
    replicatedVar: float32
  #Notice you can pass Cond and RepNotify as parameters.
  uprops(EditAnywhere, BlueprintReadWrite, Replicated, Cond=InitialOnly, RepNotify=Always):
    anotherReplicatedVar: float32
  
  defaults:              
    #When an actor is set to be replicated. On spawn (only the server should spawn it), the server will replicate the actor to all clients.
    #If replicate movement is enabled, it will also replicate the Location, Rotation and Velocity of the Actor.
    bReplicates = true 
    setReplicateMovement true    

  ufuncs:
    proc onRepReplicatedVar() = 
      #Notice this is only called in the client by default (like in C++). One can call it in the server by calling it explicitly
      printString self, "replicatedVar has been replicated", duration = 5

    proc beginPlay() = 
      if self.hasAuthority: #You can only modify var to be replicated in the server
        self.replicatedVar = 10 
        printString self, "replicatedVar has been set to 10", duration = 5
      let role = self.getLocalRole()
      log "Role: {role}"      
    
  ufuncs(BlueprintCallable, Reliable, Server):
    proc serverRPCTest(n: float32) = 
      assert self.hasAuthority()
      printString self, "serverRPCTest", duration = 5
      self.multicastRPCTest()
      self.clientRPCTest()

  ufuncs(BlueprintCallable, Client):
    proc clientRPCTest() = 
      printString self, "clientRPCTest", duration = 5

  ufuncs(BlueprintCallable, NetMulticast):
    proc multicastRPCTest() = 
      printString self, "multicastRPCTest", duration = 5


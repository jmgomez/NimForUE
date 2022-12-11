  #include "UEDeps.h"
  class UNimObject : public UObject {
    public:
      
  };
  
class ANimActor : public AActor {
    public:
      virtual USceneComponent* GetDefaultAttachComponent() const override;
  };
  
  
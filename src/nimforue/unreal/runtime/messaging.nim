import ../coreuobject/[uobject, nametypes]
import ../core/containers/[unrealstring]



type 
  FMessageEndpoint* {.importcpp.} = object
  FMessageEndpointBuilder* {.importcpp.} = object
  TFunctionMessageHandler*[M] {.importcpp.} = object #TODO

proc makeFMessageEndpointBuilder*(name:FName): FMessageEndpointBuilder {.importcpp: "FMessageEndpointBuilder(#)".} #equivalent: FMessageEndpoint::Builder(\"MyEndpoint\")

#[
 /**
	 * Adds a message handler for the given type of messages (via TFunction object).
	 *
	 * It is legal to configure multiple handlers for the same message type. Each
	 * handler will be executed when a message of the specified type is received.
	 *
	 * This overload is used to register functions that are compatible with TFunction
	 * function objects, such as global and static functions, as well as lambdas.
	 *
	 * @param MessageType The type of messages to handle.
	 * @param Function The function object handling the messages.
	 * @return This instance (for method chaining).
	 * @see WithCatchall, WithHandler
	 */
	 */
]#
# proc handling*[M, H](handler : ptr M, )
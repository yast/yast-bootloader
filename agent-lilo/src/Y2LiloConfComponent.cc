

#include "Y2LiloConfComponent.h"
#include <scr/SCRInterpreter.h>
#include "LiloAgent.h"


Y2LiloConfComponent::Y2LiloConfComponent()
    : interpreter(0),
      agent(0)
{
}


Y2LiloConfComponent::~Y2LiloConfComponent()
{
    if (interpreter) {
        delete interpreter;
        delete agent;
    }
}


bool
Y2LiloConfComponent::isServer() const
{
    return true;
}


string
Y2LiloConfComponent::name() const
{
    return "ag_liloconf";
}


YCPValue
Y2LiloConfComponent::evaluate(const YCPValue& value)
{
    if (!interpreter) {
	agent = new LiloAgent();
	interpreter = new SCRInterpreter(agent);
    }
    
    return interpreter->evaluate(value);
}

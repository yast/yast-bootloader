/*
 * YaST2: Core system
 *
 * Description:
 *   YaST2 SCR: Prom agent implementation
 *
 * Authors:
 *   Thorsten Kukuk <kukuk@suse.de>
 *
 * $Id$
 */

#include "Y2PromAgentComponent.h"
#include <scr/SCRInterpreter.h>
#include "PromAgent.h"


Y2PromAgentComponent::Y2PromAgentComponent()
    : interpreter(0),
      agent(0)
{
}


Y2PromAgentComponent::~Y2PromAgentComponent()
{
    if (interpreter) {
        delete interpreter;
        delete agent;
    }
}


bool
Y2PromAgentComponent::isServer() const
{
    return true;
}

string
Y2PromAgentComponent::name() const
{
    return "ag_prom";
}


YCPValue Y2PromAgentComponent::evaluate(const YCPValue& value)
{
    if (!interpreter) {
        agent = new PromAgent();
        interpreter = new SCRInterpreter(agent);
    }
    
    return interpreter->evaluate(value);
}


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

#include "Y2CCPromAgent.h"
#include "Y2PromAgentComponent.h"


Y2CCPromAgent::Y2CCPromAgent()
    : Y2ComponentCreator(Y2ComponentBroker::BUILTIN)
{
}


bool
Y2CCPromAgent::isServerCreator() const
{
    return true;
}


Y2Component *
Y2CCPromAgent::create(const char *name) const
{
    if (!strcmp(name, "ag_prom")) return new Y2PromAgentComponent();
    else return 0;
}


Y2CCPromAgent g_y2ccag_prom;



/*
 *  Author: Arvin Schnell <arvin@suse.de>
 */


#include <scr/Y2AgentComponent.h>
#include <scr/Y2CCAgentComponent.h>
#include <scr/SCRInterpreter.h>

#include "PromAgent.h"


typedef Y2AgentComp <PromAgent> Y2PromAgentComp;

Y2CCAgentComp <Y2PromAgentComp> g_y2ccag_prom ("ag_prom");


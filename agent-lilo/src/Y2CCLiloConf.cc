

/*
 *  Author: Arvin Schnell <arvin@suse.de>
 */


#include <scr/Y2AgentComponent.h>
#include <scr/Y2CCAgentComponent.h>

#include "LiloAgent.h"


typedef Y2AgentComp <LiloAgent> Y2LiloAgentComp;

Y2CCAgentComp <Y2LiloAgentComp> g_y2ccag_liloconf ("ag_liloconf");


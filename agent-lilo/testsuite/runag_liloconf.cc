/*---------------------------------------------------------------------\
|                                                                      |
|                      __   __    ____ _____ ____                      |
|                      \ \ / /_ _/ ___|_   _|___ \                     |
|                       \ V / _` \___ \ | |   __) |                    |
|                        | | (_| |___) || |  / __/                     |
|                        |_|\__,_|____/ |_| |_____|                    |
|                                                                      |
|                               core system                            |
|                                                        (C) SuSE GmbH |
\----------------------------------------------------------------------/

   File:       runag_liloconf.cc

   Author:     Arvin Schnell <arvin@suse.de>
               Jan Holesovsky <kendy@suse.cz>
   Maintainer: Arvin Schnell <arvin@suse.de>

/-*/

#include <scr/run_agent.h>

#include "../src/LiloAgent.h"

int main (int argc, char *argv[])
{
    run_agent <LiloAgent>(argc, argv, true);
}


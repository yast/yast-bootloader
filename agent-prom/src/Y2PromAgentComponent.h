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

#ifndef Y2PromAgentComponent_h
#define Y2PromAgentComponent_h

#include "Y2.h"

class SCRInterpreter;
class PromAgent;


class Y2PromAgentComponent : public Y2Component
{
    private:
        SCRInterpreter *interpreter;
        PromAgent *agent;
    
    public:
    
        /**
         * Default constructor
         */
        Y2PromAgentComponent();
        
        /**
         * Destructor
         */
        ~Y2PromAgentComponent();
        
        /**
         * Returns true: The scr is a server component
         */
        bool isServer() const;
        
        /**
         * Returns the name of the module.
         */
        virtual string name() const;
        
        /**
         * Starts the server, if it is not already started and does
         * what a server is good for: Gets a command, evaluates (or
         * executes) it and returns the result.
         * @param command The command to be executed. Any YCPValueRep
         * can be executed. The execution is performed by some
         * YCPInterpreter.
         */
        virtual YCPValue evaluate(const YCPValue& command);
};

#endif

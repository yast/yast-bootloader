// -*- c++ -*-

#ifndef __Y2CCRCCONFIGCOMPONENT
#define __Y2CCRCCONFIGCOMPONENT

#include "Y2.h"

class SCRInterpreter;
class LiloAgent;

class Y2LiloConfComponent : public Y2Component
{
    SCRInterpreter *interpreter;
    LiloAgent *agent;
    
public:
    /**
     * Create a new Y2RcConfigComponent
     */
    Y2LiloConfComponent();
    
    /**
     * Cleans up
     */
    ~Y2LiloConfComponent();
    
    /**
     * Returns true: The scr is a server component
     */
    bool isServer() const;
    
    /**
     * Returns true: The scr is a server component
     */
    virtual string name() const;
    
    /**
     * Evalutas a command to the scr
     */
    virtual YCPValue evaluate(const YCPValue& command);
};

#endif

#include "Y2CCLiloConf.h"
#include "Y2LiloConfComponent.h"


Y2CCLiloConf::Y2CCLiloConf()
    : Y2ComponentCreator(Y2ComponentBroker::BUILTIN)
{
}


bool
Y2CCLiloConf::isServerCreator() const
{
    return true;
}


Y2Component *
Y2CCLiloConf::create(const char *name) const {
    if (!strcmp(name, "ag_liloconf")) return new Y2LiloConfComponent();
    else return 0;
}

Y2CCLiloConf g_y2ccag_liloconf;

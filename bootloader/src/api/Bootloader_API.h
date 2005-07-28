#include <map>
#include <deque>
#include <string>
bool commitSettings( );
std::map<std::string,std::string >* getDeviceMapping( );
std::map<std::string,std::string >* getFilesContents( );
std::map<std::string,std::string >* getGlobalOptions( );
std::deque<std::map<std::string,std::string >* >* getSections( );
void initBootloader( std::string p1 );
bool initConfig( );
bool setDeviceMapping( std::map<std::string,std::string >* p1 );
bool setFilesFromStrings( std::map<std::string,std::string >* p1 );
bool setGlobalOptions( std::map<std::string,std::string >* p1 );
bool setMDArrays( std::map<std::string,std::deque<std::string >* >* p1 );
bool setMountPoints( std::map<std::string,std::string >* p1 );
bool setPartitions( std::deque<std::deque<std::string >* >* p1 );
bool setSections( std::deque<std::map<std::string,std::string >* >* p1 );
void updateBootloader( );

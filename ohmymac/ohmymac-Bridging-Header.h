//
//  Use this file to import your target's public headers that you would like to expose to Swift.
//

#import "depdencies/spaceid/Helper/PFMoveApplication.h"
#import <Foundation/Foundation.h>

id CGSCopyManagedDisplaySpaces(int conn);
int _CGSDefaultConnection();

id CGSCopyWindowsWithOptionsAndTags(int conn, unsigned owner, NSArray *spids, unsigned options, unsigned long long *setTags, unsigned long long *clearTags);

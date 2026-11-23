#import <Cocoa/Cocoa.h>
#import <SystemConfiguration/SystemConfiguration.h>
#import <arpa/inet.h>

static void tell(NSString *title, NSString *body) {
    NSAlert *a = [NSAlert new];
    a.messageText = title;
    a.informativeText = body;
    [a runModal];
}
static NSString *quote(NSString *s) {
    return [NSString stringWithFormat:@"'%@'",[s stringByReplacingOccurrencesOfString:@"'" withString:@"'\\''"]];
}
static NSArray *dns(SCNetworkServiceRef service) {
    SCNetworkProtocolRef proto = SCNetworkServiceCopyProtocol(service,kSCNetworkProtocolTypeDNS);
    if (!proto) return @[];
    NSDictionary *config = (__bridge NSDictionary *)SCNetworkProtocolGetConfiguration(proto);
    NSArray *addresses = [config[(__bridge NSString *)kSCPropNetDNSServerAddresses] copy] ?: @[];
    CFRelease(proto);
    return addresses;
}
int main(void) { @autoreleasepool {
    [NSApplication sharedApplication];
    [NSApp setActivationPolicy:NSApplicationActivationPolicyRegular];
    [NSApp activateIgnoringOtherApps:YES];
    SCPreferencesRef prefs = SCPreferencesCreate(NULL,CFSTR("DNS Switch"),NULL);
    SCNetworkSetRef set = prefs ? SCNetworkSetCopyCurrent(prefs) : NULL;
    NSArray *services = set ? CFBridgingRelease(SCNetworkSetCopyServices(set)) : nil;
    NSPopUpButton *net = [[NSPopUpButton alloc] initWithFrame:NSMakeRect(0,0,300,26) pullsDown:NO];
    for (id obj in services) {
        SCNetworkServiceRef service = (__bridge SCNetworkServiceRef)obj;
        if (!SCNetworkServiceGetEnabled(service)) continue;
        NSString *name = (__bridge NSString *)SCNetworkServiceGetName(service);
        if (!name) continue;
        [net addItemWithTitle:name];
        net.lastItem.representedObject = obj;
    }
    if (!net.numberOfItems) { tell(@"No network services found",@"Enable Wi-Fi or Ethernet and reopen DNS Switch."); return 0; }
    if ([net itemWithTitle:@"Wi-Fi"]) [net selectItemWithTitle:@"Wi-Fi"];
    NSAlert *pick = [NSAlert new];
    pick.messageText = @"DNS Switch";
    pick.informativeText = @"Choose the network service to configure.";
    pick.accessoryView = net;
    [pick addButtonWithTitle:@"Continue"];
    [pick addButtonWithTitle:@"Cancel"];
    if ([pick runModal] != NSAlertFirstButtonReturn) return 0;
    SCNetworkServiceRef service = (__bridge SCNetworkServiceRef)net.selectedItem.representedObject;
    NSString *name = net.titleOfSelectedItem;
    NSString *key = [@"original." stringByAppendingString:(__bridge NSString *)SCNetworkServiceGetServiceID(service)];
    NSArray *old = dns(service);
    NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
    NSArray *saved = [defaults arrayForKey:key];
    NSAlert *edit = [NSAlert new];
    edit.messageText = [@"DNS for " stringByAppendingString:name];
    edit.informativeText = [NSString stringWithFormat:@"Current setting: %@\n\nUse Cloudflare below, or enter your own DNS addresses separated by commas.",old.count ? [old componentsJoinedByString:@", "] : @"Automatic"];
    NSTextField *field = [[NSTextField alloc] initWithFrame:NSMakeRect(0,0,340,26)];
    field.stringValue = @"1.1.1.1, 1.0.0.1";
    edit.accessoryView = field;
    [edit addButtonWithTitle:@"Apply DNS"];
    [edit addButtonWithTitle:@"Automatic"];
    [edit addButtonWithTitle:@"Restore Previous"].enabled = saved != nil;
    [edit addButtonWithTitle:@"Cancel"];
    NSInteger choice = [edit runModal] - NSAlertFirstButtonReturn;
    if (choice < 0 || choice > 2) return 0;
    NSMutableArray *addresses = [NSMutableArray array];
    if (choice == 2) [addresses addObjectsFromArray:saved];
    if (choice == 0) {
        for (NSString *token in [field.stringValue componentsSeparatedByString:@","]) {
            NSString *s = [token stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
            struct in6_addr address;
            if (inet_pton(AF_INET,s.UTF8String,&address)!=1 && inet_pton(AF_INET6,s.UTF8String,&address)!=1) {
                tell(@"Invalid DNS address",@"Enter IPv4 or IPv6 addresses separated by commas."); return 1;
            }
            [addresses addObject:s];
        }
    }
    NSMutableArray *args = [NSMutableArray arrayWithObjects:@"/usr/sbin/networksetup",@"-setdnsservers",quote(name),nil];
    for (NSString *s in addresses) [args addObject:quote(s)];
    if (!addresses.count) [args addObject:@"Empty"];
    NSTask *task = [NSTask new];
    task.executableURL = [NSURL fileURLWithPath:@"/usr/bin/osascript"];
    task.arguments = @[@"-e",@"on run argv",@"-e",@"do shell script (item 1 of argv) with administrator privileges",@"-e",@"end run",@"--",[args componentsJoinedByString:@" "]];
    NSPipe *pipe = [NSPipe pipe];
    task.standardError = pipe;
    task.standardOutput = pipe;
    if (!saved) { [defaults setObject:old forKey:key]; [defaults synchronize]; }
    NSError *error;
    if (![task launchAndReturnError:&error]) { tell(@"Could not apply DNS",error.localizedDescription); return 1; }
    NSData *data = [pipe.fileHandleForReading readDataToEndOfFile];
    [task waitUntilExit];
    if (task.terminationStatus) { tell(@"DNS change was unsuccessful",[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] ?: @"Try again."); return 1; }
    SCPreferencesSynchronize(prefs);
    SCNetworkServiceRef latest = SCNetworkServiceCopy(prefs,SCNetworkServiceGetServiceID(service));
    if (!latest || ![dns(latest) isEqualToArray:addresses]) { tell(@"Could not verify the change",@"Check DNS in System Settings."); return 1; }
    if (choice == 2) [defaults removeObjectForKey:key];
    tell(@"DNS settings saved",addresses.count ? [addresses componentsJoinedByString:@", "] : @"Your network supplies DNS automatically.");
    return 0;
} }

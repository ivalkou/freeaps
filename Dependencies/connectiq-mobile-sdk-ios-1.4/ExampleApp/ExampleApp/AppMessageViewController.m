//
//  AppMessageViewController.m
//  ExampleApp
//
//  Copyright (c) 2014 Garmin. All rights reserved.
//

#import "AppMessageViewController.h"
#import "TableEntry.h"

// --------------------------------------------------------------------------------
#pragma mark - LITERAL CONSTANTS
// --------------------------------------------------------------------------------

#define LogMessage(_format_, ...) [self logMessage:[NSString stringWithFormat:_format_, ##__VA_ARGS__]]

static const int kMaxLogMessages = 200;

// --------------------------------------------------------------------------------
#pragma mark - PRIVATE DECLARATIONS
// --------------------------------------------------------------------------------

@interface AppMessageViewController () <IQDeviceEventDelegate, IQAppMessageDelegate, UITableViewDataSource, UITableViewDelegate>

@property (nonatomic, weak) IBOutlet UITextView *logView;
@property (nonatomic, weak) IBOutlet UITableView *tableView;

@property (nonatomic, strong) AppInfo *appInfo;
@property (nonatomic, readonly) IQDevice *device;
@property (nonatomic, strong) NSArray *tableEntries;
@property (nonatomic, strong) NSMutableArray *logMessages;

@end

// --------------------------------------------------------------------------------
#pragma mark - CLASS DEFINITION
// --------------------------------------------------------------------------------

@implementation AppMessageViewController

// --------------------------------------------------------------------------------
#pragma mark - STATIC METHODS
// --------------------------------------------------------------------------------

// --------------------------------------------------------------------------------
#pragma mark - INITIALIZERS AND DEALLOCATOR
// --------------------------------------------------------------------------------

- (instancetype)initWithAppInfo:(AppInfo *)appInfo {
    if ((self = [super initWithNibName:nil bundle:nil])) {
        _appInfo = appInfo;
        _logMessages = [NSMutableArray array];
        _tableEntries = @[
            [TableEntry entryWithLabel:@"Send open app request" message:nil],
            [TableEntry entryWithLabel:@"Hello world" message:@"Hello World!"],
            [TableEntry entryWithLabel:@"String (short)" message:@"Hi"],
            [TableEntry entryWithLabel:@"String (medium)" message:@"Why hello there, good world! This is a medium-length string."],
            [TableEntry entryWithLabel:@"String (long)" message:@"Lorem ipsum dolor sit amet, pri ex epicuri luptatum, cum tantas partem fastidii an. Ea quot iudicabit vim, vis copiosae repudiandae at. Pri ut agam animal epicuri, nam cu omnis latine voluptatibus. Est dicat viderer ei, at possit sapientem ullamcorper vix, et eum virtute dolorum intellegat. No summo animal forensibus sit, singulis dissentiunt vix at, id congue theophrastus cum. Eam ex semper molestiae, te porro labore mel."],
            [TableEntry entryWithLabel:@"String (absurd)" message:@"Lorem ipsum dolor sit amet, consectetur adipiscing elit. Donec at ultricies enim. Quisque venenatis sed nisl a molestie. Sed iaculis commodo erat nec dignissim. Aenean vitae fermentum diam, fringilla vehicula orci. Donec quis lorem velit. Vivamus sit amet mauris volutpat, faucibus tellus quis, fringilla ligula. Phasellus tempor auctor malesuada. Duis tempor id dolor et sagittis. Vivamus sem magna, condimentum et lacus at, semper pretium nunc. Phasellus volutpat, metus eget egestas dictum, massa mauris dictum justo, quis viverra neque felis ut augue. In hendrerit eros vitae dui laoreet sodales. Praesent vitae odio vitae arcu luctus imperdiet. Phasellus venenatis ex in nunc finibus, ac elementum sapien aliquam. Etiam pulvinar tincidunt mauris non faucibus. Vestibulum ut enim sit amet metus sodales porttitor. Proin ut venenatis orci, nec volutpat neque. Integer pretium risus vel nibh fringilla, vel egestas lectus semper. Integer eleifend mauris id odio blandit ornare. In nec dui aliquam, pulvinar massa ut, mollis mi. Nunc nec mauris est. Nunc efficitur eget ligula et dapibus. Vestibulum varius urna quam, eget tristique magna fringilla id. Quisque blandit dolor mattis metus interdum lacinia. In in accumsan ligula. Interdum et malesuada fames ac ante ipsum primis in faucibus. Mauris nunc nunc, interdum nec tempus ut, facilisis vel eros. Curabitur vitae tellus nec elit semper faucibus. Donec sed diam facilisis, porttitor urna vitae, interdum sapien. Nunc nec eros at leo sollicitudin fermentum at et orci. Proin erat lorem, tincidunt id nunc vel, egestas sodales erat. Praesent sem augue, aliquam vulputate cursus quis, dapibus quis nisl. Aenean tincidunt sapien eu tincidunt rutrum. Aenean ultricies auctor magna eget tempor. Class aptent taciti sociosqu ad litora torquent per conubia nostra, per inceptos himenaeos. Phasellus id massa diam. Etiam at ipsum id nisi finibus ultrices gravida eu est. Fusce at velit a urna pulvinar mollis sit amet vel quam. Vivamus mi ante, tempus id lacus sit amet, laoreet condimentum lectus. Nulla facilisi. Morbi eget nisl non nibh maximus maximus a a erat. Nulla nec pellentesque ex. Maecenas malesuada ante ac magna vestibulum, id tincidunt nisi vestibulum. Vestibulum at magna eu dolor finibus cursus fringilla a elit. Etiam a nunc in lacus maximus viverra. Nulla bibendum, tortor ac ultrices pulvinar, magna mi tristique tellus, sed mattis magna mauris et arcu. Donec consequat tortor et ligula condimentum dignissim. Aliquam at massa et massa blandit elementum nec sed nunc. Fusce tempor quam tellus, eu suscipit elit consequat et. Cras quis massa at nulla aliquet tristique eget sit amet eros. In pulvinar massa et orci rhoncus lacinia. Quisque semper feugiat erat, sit amet facilisis justo feugiat a. Nullam mattis lorem in nisl maximus, sed suscipit enim tempus. Nam sed aliquam elit, quis pharetra mi. Aliquam erat volutpat. Cras dapibus vel sapien non aliquet. Etiam lacinia tempus euismod. Donec ultricies est non ante eleifend, et blandit lorem consequat. Nulla tincidunt massa et tellus ornare, eu ornare nisl auctor. Nam ac posuere ipsum. Vestibulum ante ipsum primis in faucibus orci luctus et ultrices posuere cubilia Curae; Pellentesque habitant morbi tristique senectus et netus et malesuada fames ac turpis egestas. Quisque porttitor, arcu et pharetra porta, tellus ipsum vestibulum ex, ac dictum risus mauris a massa. Phasellus in quam dui. Vestibulum et ligula at justo scelerisque posuere. Cras pretium ac nisi vel tincidunt. Suspendisse aliquam, tellus ac consectetur dapibus, turpis sapien dictum odio, sit amet fermentum ex elit at diam. In hac habitasse platea dictumst. Ut bibendum pharetra aliquet. Aenean condimentum lacus ligula, at auctor sem semper at. Aenean sollicitudin neque augue, at tempor est commodo eu. Mauris massa tortor, mollis posuere nisi vitae, efficitur volutpat odio. Phasellus faucibus pellentesque augue, ut vulputate augue condimentum vel. Aliquam eu gravida dui, sed vestibulum justo. Curabitur nec mauris augue. Sed eu lobortis magna. Suspendisse bibendum est hendrerit hendrerit dignissim. Sed vel nisi magna. Mauris ultricies tincidunt porttitor. Praesent congue diam turpis, eu feugiat neque sollicitudin sed. Nullam molestie est posuere odio luctus volutpat. Nam lacinia nisl vel ex sodales posuere. Curabitur quis aliquam nulla. Ut dapibus sem arcu, a posuere dolor hendrerit eleifend. Curabitur ornare eu lorem eget egestas. Vivamus venenatis porta ipsum, vitae efficitur felis porttitor ut. Donec lobortis ornare suscipit. Etiam eget dolor ut felis condimentum elementum. Duis pretium eget nunc a tempor. Pellentesque vel dui leo. Ut condimentum risus eu velit sollicitudin semper. Nullam pellentesque ut turpis vitae sollicitudin. Duis blandit feugiat odio sit amet fermentum. Quisque ultrices dapibus metus, sed laoreet mi blandit ut. Sed at dui vitae turpis suscipit varius et eu velit. Donec mattis augue placerat pharetra vehicula. Nam convallis mauris ut turpis ultricies, volutpat imperdiet eros viverra. Etiam nisl est, accumsan at scelerisque sit amet, elementum quis ex. Curabitur ac sapien lacus. Phasellus et eleifend nisl. Donec eu eleifend felis, id ultrices nibh. In hendrerit arcu quis justo blandit varius sed eget libero. Nulla egestas magna vehicula, pellentesque nibh quis, congue tortor. Ut sed hendrerit nisl, id posuere lorem. Suspendisse sodales est id mauris pretium porttitor. Integer risus magna, lacinia nec lorem eu, pulvinar mattis turpis. Proin aliquam turpis velit, quis placerat felis sollicitudin at. Fusce condimentum quam eget lorem interdum, et ornare urna fermentum. Quisque elit arcu, laoreet tempus leo id, blandit vehicula mauris. Class aptent taciti sociosqu ad litora torquent per conubia nostra, per inceptos himenaeos. Nullam mauris mauris, sollicitudin id tortor vitae, condimentum suscipit lectus. Morbi congue sit amet risus quis egestas. Cum sociis natoque penatibus et magnis dis parturient montes, nascetur ridiculus mus. Praesent pellentesque metus eget quam pulvinar mollis. In ut neque risus. Curabitur massa erat, dapibus a lacus eget, faucibus rhoncus risus. Aenean imperdiet dolor quis commodo pulvinar. Vivamus porttitor diam fermentum interdum posuere."],
            [TableEntry entryWithLabel:@"Array" message:@[@"An", @"array", @"of", @"strings", @"and", @"one", @"pi", @(3.14159265359)]],
            [TableEntry entryWithLabel:@"Dictionary" message:@{@"key1" : @"value1", @"key2" : [NSNull null], @"key3" : @(42), @"key4" : @(123.456)}],
            [TableEntry entryWithLabel:@"Complex Object" message:@[
                @"A string",
                @[@"A", @"nested", @"array"],
                @{@"key1" : @"A nested dictionary",
                  @"key2" : @"three strings...",
                  @"key3" : @"and one array",
                  @"key4" : @[
                      @"This array has two strings",
                      @"and a nested dictionary!",
                      @{@"one"     : @(1),
                        @"two"     : @(2),
                        @"three"   : @(3),
                        @"four"    : @(4),
                        @"five"    : @(5),
                        @(1.61803) : @"G.R."
                      },
                  ],
                },
                @"And one last null",
                [NSNull null],
            ]],
        ];
    }
    return self;
}

// --------------------------------------------------------------------------------
#pragma mark - VIEW LIFECYCLE
// --------------------------------------------------------------------------------

- (void)viewDidLoad {
    [super viewDidLoad];

    self.navigationItem.title = [NSString stringWithFormat:@"%@ on %@", self.appInfo.name, self.device.friendlyName];

    self.tableView.delegate = self;
    self.tableView.dataSource = self;
}

- (void)viewWillAppear:(BOOL)animated {
    [[ConnectIQ sharedInstance] registerForDeviceEvents:self.device delegate:self];
    [[ConnectIQ sharedInstance] registerForAppMessages:self.appInfo.app delegate:self];
    [self.tableView reloadData];
}

- (void)viewDidDisappear:(BOOL)animated {
    [[ConnectIQ sharedInstance] unregisterForAllDeviceEvents:self];
    [[ConnectIQ sharedInstance] unregisterForAllAppMessages:self];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

// --------------------------------------------------------------------------------
#pragma mark - DYNAMIC PROPERTIES
// --------------------------------------------------------------------------------

- (IQDevice *)device {
    return self.appInfo.app.device;
}

// --------------------------------------------------------------------------------
#pragma mark - METHODS (UITableView)
// --------------------------------------------------------------------------------

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.tableEntries.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    TableEntry *entry = self.tableEntries[indexPath.row];

    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"commandcell"];
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"commandcell"];
    }

    cell.textLabel.text = entry.label;
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    TableEntry *entry = self.tableEntries[indexPath.row];
    if(indexPath.row == 0){
        [self openAppRequest];
    } else {
        [self sendMessage:entry.message];
    }
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
}


// --------------------------------------------------------------------------------
#pragma mark - METHODS (IQDeviceEventDelegate)
// --------------------------------------------------------------------------------

- (void)deviceStatusChanged:(IQDevice *)device status:(IQDeviceStatus)status {
    // We've only registered to receive status updates for one device, so we don't
    // need to check the device parameter here. We know it's our device.
    if (status != IQDeviceStatus_Connected) {
        // This page's device is no longer connected. Pop back to the device list.
        [[ConnectIQ sharedInstance] unregisterForAllAppMessages:self];
        [self.navigationController popToRootViewControllerAnimated:YES];
    }
}

// --------------------------------------------------------------------------------
#pragma mark - METHODS (IQAppMessageDelegate)
// --------------------------------------------------------------------------------

- (void)receivedMessage:(id)message fromApp:(IQApp *)app {
    // We've only registered to receive messages from our app, so we don't need to
    // check the app parameter here. We know it's our app.
    LogMessage(@"Received message: '%@'", message);
}

// --------------------------------------------------------------------------------
#pragma mark - METHODS
// --------------------------------------------------------------------------------
- (void)openAppRequest {
    LogMessage(@"Sending open app request message...");
    [[ConnectIQ sharedInstance] openAppRequest:self.appInfo.app completion:^(IQSendMessageResult sendDataTaskResult) {
        LogMessage(@"Open App Request finished with result %@", NSStringFromSendMessageResult(sendDataTaskResult));
    }];
}

- (void)sendMessage:(id)message {
    LogMessage(@"Sending message: '%@'...", message);
    [[ConnectIQ sharedInstance] sendMessage:message toApp:self.appInfo.app progress:^(uint32_t sentBytes, uint32_t totalBytes) {
        double percent = 100 * sentBytes / (double)totalBytes;
        LogMessage(@"%02.2f%% - %u/%u", percent, sentBytes, totalBytes);
    } completion:^(IQSendMessageResult result) {
        LogMessage(@"Send message finished with result %@", NSStringFromSendMessageResult(result));
    }];
}

- (void)logMessage:(NSString *)message {
    static NSDateFormatter *formatter;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        formatter = [[NSDateFormatter alloc] init];
        formatter.dateFormat = @"MM-dd hh:mm:ss";
    });
    NSLog(@"%@", message);
    message = [NSString stringWithFormat:@"[%@] %@", [formatter stringFromDate:[NSDate date]], message];
    [self.logMessages addObject:message];
    while (self.logMessages.count > kMaxLogMessages) {
        [self.logMessages removeObjectAtIndex:0];
    }
    self.logView.text = [self.logMessages componentsJoinedByString:@"\n"];
    [self.logView.layoutManager ensureLayoutForTextContainer:self.logView.textContainer];
    [self.logView scrollRangeToVisible:NSMakeRange(self.logView.text.length-1, 1)];
}

@end

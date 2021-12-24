//
//  DeviceListViewController.m
//  ExampleApp
//
//  Copyright (c) 2014 Garmin. All rights reserved.
//

#import "DeviceListViewController.h"
#import <ConnectIQ/ConnectIQ.h>
#import "DeviceManager.h"
#import "DeviceTableViewCell.h"
#import "DeviceAppListViewController.h"

// --------------------------------------------------------------------------------
#pragma mark - LITERAL CONSTANTS
// --------------------------------------------------------------------------------

// --------------------------------------------------------------------------------
#pragma mark - PRIVATE DECLARATIONS
// --------------------------------------------------------------------------------

@interface DeviceListViewController () <DeviceManagerDelegate, IQDeviceEventDelegate, UITableViewDataSource, UITableViewDelegate>

@property (nonatomic, weak) IBOutlet UITableView *tableView;
@property (nonatomic, weak) IBOutlet UIButton *button;

@property (nonatomic, strong) DeviceManager *deviceManager;

@end

// --------------------------------------------------------------------------------
#pragma mark - CLASS DEFINITION
// --------------------------------------------------------------------------------

@implementation DeviceListViewController

// --------------------------------------------------------------------------------
#pragma mark - STATIC METHODS
// --------------------------------------------------------------------------------

// --------------------------------------------------------------------------------
#pragma mark - INITIALIZERS AND DEALLOCATOR
// --------------------------------------------------------------------------------

// --------------------------------------------------------------------------------
#pragma mark - VIEW LIFECYCLE
// --------------------------------------------------------------------------------

- (void)viewDidLoad {
    [super viewDidLoad];

    self.navigationItem.title = @"Connect IQ Devices";

    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    UINib *nib = [UINib nibWithNibName:@"DeviceTableViewCell" bundle:nil];
    [self.tableView registerNib:nib forCellReuseIdentifier:@"iqdevicecell"];

    self.deviceManager = [DeviceManager sharedManager];
    self.deviceManager.delegate = self;
}

- (void)viewWillAppear:(BOOL)animated {
    for (IQDevice *device in [self.deviceManager allDevices]) {
        NSLog(@"Registering for device events from '%@'", device.friendlyName);
        [[ConnectIQ sharedInstance] registerForDeviceEvents:device delegate:self];
    }
    [self.tableView reloadData];
}

- (void)viewDidDisappear:(BOOL)animated {
    [[ConnectIQ sharedInstance] unregisterForAllDeviceEvents:self];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

// --------------------------------------------------------------------------------
#pragma mark - METHODS (IBAction)
// --------------------------------------------------------------------------------

- (IBAction)buttonPressed:(id)sender {
    [[ConnectIQ sharedInstance] showConnectIQDeviceSelection];
}

// --------------------------------------------------------------------------------
#pragma mark - METHODS (UITableView)
// --------------------------------------------------------------------------------

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [self.deviceManager allDevices].count;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return 85.0f;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    IQDevice *device = [self.deviceManager allDevices][indexPath.row];
    IQDeviceStatus status = [[ConnectIQ sharedInstance] getDeviceStatus:device];
    DeviceTableViewCell *cell = [self.tableView dequeueReusableCellWithIdentifier:@"iqdevicecell" forIndexPath:indexPath];
    cell.nameLabel.text = device.friendlyName;
    cell.modelLabel.text = device.modelName;
    switch (status) {
        case IQDeviceStatus_InvalidDevice:
            cell.statusLabel.text = @"Invalid Device";
            cell.enabled = NO;
            break;

        case IQDeviceStatus_BluetoothNotReady:
            cell.statusLabel.text = @"Bluetooth Off";
            cell.enabled = NO;
            break;

        case IQDeviceStatus_NotFound:
            cell.statusLabel.text = @"Not Found";
            cell.enabled = NO;
            break;

        case IQDeviceStatus_NotConnected:
            cell.statusLabel.text = @"Not Connected";
            cell.enabled = NO;
            break;

        case IQDeviceStatus_Connected:
            cell.statusLabel.text = @"Connected";
            cell.enabled = YES;
            break;
    }
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    IQDevice *device = [self.deviceManager allDevices][indexPath.row];
    IQDeviceStatus status = [[ConnectIQ sharedInstance] getDeviceStatus:device];
    if (status == IQDeviceStatus_Connected) {
        DeviceAppListViewController *vc = [[DeviceAppListViewController alloc] initWithDevice:device];
        [self.navigationController pushViewController:vc animated:YES];
    }
}

// --------------------------------------------------------------------------------
#pragma mark - METHODS (DeviceManagerDelegate)
// --------------------------------------------------------------------------------

- (void)devicesChanged {
    for (IQDevice *device in [self.deviceManager allDevices]) {
        [[ConnectIQ sharedInstance] registerForDeviceEvents:device delegate:self];
    }
    [self.tableView reloadData];
}

// --------------------------------------------------------------------------------
#pragma mark - METHODS
// --------------------------------------------------------------------------------

- (void)deviceStatusChanged:(IQDevice *)device status:(IQDeviceStatus)status {
    [self.tableView reloadData];
}

@end

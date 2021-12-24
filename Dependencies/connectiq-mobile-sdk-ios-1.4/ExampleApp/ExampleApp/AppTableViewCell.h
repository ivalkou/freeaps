//
//  AppTableViewCell.h
//  ExampleApp
//
//  Copyright (c) 2014 Garmin. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface AppTableViewCell : UITableViewCell

@property (nonatomic, strong) IBOutlet UILabel *nameLabel;
@property (nonatomic, strong) IBOutlet UILabel *installedLabel;
@property (nonatomic) BOOL enabled;

@end

//
//  SignInViewController.m
//
//  Copyright 2012 Google Inc.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

#import "SignInViewController.h"

#import <GoogleSignIn/GoogleSignIn.h>

#import "AuthInspectorViewController.h"
#import "DataPickerState.h"
#import "DataPickerViewController.h"

typedef void(^AlertViewActionBlock)(void);

@interface SignInViewController () <GIDSignInDelegate, GIDSignInUIDelegate>

@property (nonatomic, copy) void (^confirmActionBlock)(void);
@property (nonatomic, copy) void (^cancelActionBlock)(void);

@end

static NSString *const kPlaceholderUserName = @"<Name>";
static NSString *const kPlaceholderEmailAddress = @"<Email>";
static NSString *const kPlaceholderAvatarImageName = @"PlaceholderAvatar.png";

// Labels for the cells that have in-cell control elements.
static NSString *const kGetUserProfileCellLabel = @"Get user Basic Profile";
static NSString *const kButtonWidthCellLabel = @"Width";

// Labels for the cells that drill down to data pickers.
static NSString *const kColorSchemeCellLabel = @"Color scheme";
static NSString *const kStyleCellLabel = @"Style";

// Strings for Alert Views.
static NSString *const kSignInViewTitle = @"Sign in View";
static NSString *const kSignOutAlertViewTitle = @"Warning";
static NSString *const kSignOutAlertCancelTitle = @"Cancel";
static NSString *const kSignOutAlertConfirmTitle = @"Continue";

// Accessibility Identifiers.
static NSString *const kCredentialsButtonAccessibilityIdentifier = @"Credentials";

static NSString *const kLiveTimeCellLabel = @"Set Live Duration (.h)";
static NSString *const kLiveTimeoutIntervalCellLabel = @"Set Post TimeoutInterval (.s)";
@implementation SignInViewController {
  // This is an array of arrays, each one corresponding to the cell
  // labels for its respective section.
  NSArray *_sectionCellLabels;

  // These sets contain the labels corresponding to cells that have various
  // types (each cell either drills down to another table view, contains an
  // in-cell switch, or contains a slider).
  NSArray *_drillDownCells;
  NSArray *_switchCells;
  NSArray *_sliderCells;
  NSArray *_liveCells;

  // States storing the current set of selected elements for each data picker.
  DataPickerState *_colorSchemeState;
  DataPickerState *_styleState;

  // Map that keeps track of which cell corresponds to which DataPickerState.
  NSDictionary *_drilldownCellState;
}

#pragma mark - View lifecycle

- (void)setUp {
  _sectionCellLabels = @[
    @[ kColorSchemeCellLabel, kStyleCellLabel, kButtonWidthCellLabel ],
    @[ kGetUserProfileCellLabel ],
    @[ kLiveTimeCellLabel, kLiveTimeoutIntervalCellLabel ]
  ];

  // Groupings of cell types.
  _drillDownCells = @[
    kColorSchemeCellLabel,
    kStyleCellLabel
  ];

  _switchCells =
      @[ kGetUserProfileCellLabel ];
  _sliderCells = @[ kButtonWidthCellLabel ];
    _liveCells = @[ kLiveTimeCellLabel, kLiveTimeoutIntervalCellLabel ];
    
  // Initialize data picker states.
  NSString *dictionaryPath =
      [[NSBundle mainBundle] pathForResource:@"DataPickerDictionary"
                                      ofType:@"plist"];
  NSDictionary *configOptionsDict = [NSDictionary dictionaryWithContentsOfFile:dictionaryPath];

  NSDictionary *colorSchemeDict = [configOptionsDict objectForKey:kColorSchemeCellLabel];
  NSDictionary *styleDict = [configOptionsDict objectForKey:kStyleCellLabel];

  _colorSchemeState = [[DataPickerState alloc] initWithDictionary:colorSchemeDict];
  _styleState = [[DataPickerState alloc] initWithDictionary:styleDict];

  _drilldownCellState = @{
    kColorSchemeCellLabel :   _colorSchemeState,
    kStyleCellLabel :         _styleState
  };

  // Make sure the GIDSignInButton class is linked in because references from
  // xib file doesn't count.
  [GIDSignInButton class];

  GIDSignIn *signIn = [GIDSignIn sharedInstance];
  signIn.shouldFetchBasicProfile = YES;
  signIn.delegate = self;
  signIn.uiDelegate = self;
  signIn.scopes = @[@"https://www.googleapis.com/auth/youtube"];
}

- (id)initWithNibName:(NSString *)nibNameOrNil
               bundle:(NSBundle *)nibBundleOrNil {
  self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
  if (self) {
    [self setUp];
    self.title = kSignInViewTitle;
  }
  return self;
}

- (id)initWithCoder:(NSCoder *)aDecoder {
  self = [super initWithCoder:aDecoder];
  if (self) {
    [self setUp];
    self.title = kSignInViewTitle;
  }
  return self;
}

- (void)viewDidLoad {
  [super viewDidLoad];

  self.credentialsButton.accessibilityIdentifier = kCredentialsButtonAccessibilityIdentifier;
}

- (void)viewWillAppear:(BOOL)animated {
  [self adoptUserSettings];
  [self reportAuthStatus];
  [self updateButtons];
  [self.tableView reloadData];

  [super viewWillAppear:animated];
}

#pragma mark - GIDSignInDelegate

- (void)signIn:(GIDSignIn *)signIn
    didSignInForUser:(GIDGoogleUser *)user
           withError:(NSError *)error {
  if (error) {
    _signInAuthStatus.text = [NSString stringWithFormat:@"Status: Authentication error: %@", error];
    return;
  }
  [self reportAuthStatus];
  [self updateButtons];
}

- (void)signIn:(GIDSignIn *)signIn
    didDisconnectWithUser:(GIDGoogleUser *)user
                withError:(NSError *)error {
  if (error) {
    _signInAuthStatus.text = [NSString stringWithFormat:@"Status: Failed to disconnect: %@", error];
  } else {
    _signInAuthStatus.text = [NSString stringWithFormat:@"Status: Disconnected"];
  }
  [self reportAuthStatus];
  [self updateButtons];
}

- (void)presentSignInViewController:(UIViewController *)viewController {
  [[self navigationController] pushViewController:viewController animated:YES];
}

#pragma mark - Helper methods

// Updates the GIDSignIn shared instance and the GIDSignInButton
// to reflect the configuration settings that the user set
- (void)adoptUserSettings {
  // There should only be one selected color scheme
  for (NSString *scheme in _colorSchemeState.selectedCells) {
    if ([scheme isEqualToString:@"Light"]) {
      _signInButton.colorScheme = kGIDSignInButtonColorSchemeLight;
    } else {
      _signInButton.colorScheme = kGIDSignInButtonColorSchemeDark;
    }
  }

  // There should only be one selected style
  for (NSString *style in _styleState.selectedCells) {
    GIDSignInButtonStyle newStyle;
    if ([style isEqualToString:@"Standard"]) {
      newStyle = kGIDSignInButtonStyleStandard;
      self.signInButtonWidthSlider.enabled = YES;
    } else if ([style isEqualToString:@"Wide"]) {
      newStyle = kGIDSignInButtonStyleWide;
      self.signInButtonWidthSlider.enabled = YES;
    } else {
      newStyle = kGIDSignInButtonStyleIconOnly;
      self.signInButtonWidthSlider.enabled = NO;
    }
    if (self.signInButton.style != newStyle) {
      self.signInButton.style = newStyle;
      self.signInButtonWidthSlider.minimumValue = [self minimumButtonWidth];
    }
    self.signInButtonWidthSlider.value = _signInButton.frame.size.width;
  }
}

// Temporarily force the sign in button to adopt its minimum allowed frame
// so that we can find out its minimum allowed width (used for setting the
// range of the width slider).
- (CGFloat)minimumButtonWidth {
  CGRect frame = self.signInButton.frame;
  self.signInButton.frame = CGRectZero;

  CGFloat minimumWidth = self.signInButton.frame.size.width;
  self.signInButton.frame = frame;

  return minimumWidth;
}

- (void)reportAuthStatus {
  GIDGoogleUser *googleUser = [[GIDSignIn sharedInstance] currentUser];
  if (googleUser.authentication) {
    _signInAuthStatus.text = @"Status: Authenticated";
      
      [self startLive];
  } else {
    // To authenticate, use Google+ sign-in button.
    _signInAuthStatus.text = @"Status: Not authenticated";
      
//      [[GIDSignIn sharedInstance] signIn];
  }

  [self refreshUserInfo];
}

// Update the interface elements containing user data to reflect the
// currently signed in user.
- (void)refreshUserInfo {
  if ([GIDSignIn sharedInstance].currentUser.authentication == nil) {
    self.userName.text = kPlaceholderUserName;
    self.userEmailAddress.text = kPlaceholderEmailAddress;
    self.userAvatar.image = [UIImage imageNamed:kPlaceholderAvatarImageName];
    return;
  }
  self.userEmailAddress.text = [GIDSignIn sharedInstance].currentUser.profile.email;
  self.userName.text = [GIDSignIn sharedInstance].currentUser.profile.name;

  if (![GIDSignIn sharedInstance].currentUser.profile.hasImage) {
    // There is no Profile Image to be loaded.
    return;
  }
  // Load avatar image asynchronously, in background
  dispatch_queue_t backgroundQueue =
      dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
  __weak SignInViewController *weakSelf = self;

  dispatch_async(backgroundQueue, ^{
    NSUInteger dimension = round(self.userAvatar.frame.size.width * [[UIScreen mainScreen] scale]);
    NSURL *imageURL =
        [[GIDSignIn sharedInstance].currentUser.profile imageURLWithDimension:dimension];
    NSData *avatarData = [NSData dataWithContentsOfURL:imageURL];

    if (avatarData) {
      // Update UI from the main thread when available
      dispatch_async(dispatch_get_main_queue(), ^{
        SignInViewController *strongSelf = weakSelf;
        if (strongSelf) {
          strongSelf.userAvatar.image = [UIImage imageWithData:avatarData];
        }
      });
    }
  });
}

// Adjusts "Sign in", "Sign out", and "Disconnect" buttons to reflect
// the current sign-in state (ie, the "Sign in" button becomes disabled
// when a user is already signed in).
- (void)updateButtons {
  BOOL authenticated = ([GIDSignIn sharedInstance].currentUser.authentication != nil);

  self.signInButton.enabled = !authenticated;
  self.signOutButton.enabled = authenticated;
  self.disconnectButton.enabled = authenticated;
  self.credentialsButton.hidden = !authenticated;

  if (authenticated) {
    self.signInButton.alpha = 0.5;
    self.signOutButton.alpha = self.disconnectButton.alpha = 1.0;
  } else {
    self.signInButton.alpha = 1.0;
    self.signOutButton.alpha = self.disconnectButton.alpha = 0.5;
  }
}

#pragma mark - IBActions

- (IBAction)signOut:(id)sender {
  [[GIDSignIn sharedInstance] signOut];
  [self reportAuthStatus];
  [self updateButtons];
}

- (IBAction)disconnect:(id)sender {
  [[GIDSignIn sharedInstance] disconnect];
}

- (IBAction)showAuthInspector:(id)sender {
  AuthInspectorViewController *authInspector = [[AuthInspectorViewController alloc] init];
  [[self navigationController] pushViewController:authInspector animated:YES];
}

- (IBAction)checkSignIn:(id)sender {
  [self reportAuthStatus];
}

- (void)toggleBasicProfile:(UISwitch *)sender {
  [GIDSignIn sharedInstance].shouldFetchBasicProfile = sender.on;
}

- (void)changeSignInButtonWidth:(UISlider *)sender {
  CGRect frame = self.signInButton.frame;
  frame.size.width = sender.value;
  self.signInButton.frame = frame;
}

#pragma mark - UIAlertView Delegate

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
  if (buttonIndex == alertView.cancelButtonIndex) {
    if (_cancelActionBlock) {
      _cancelActionBlock();
    }
  } else {
    if (_confirmActionBlock) {
      _confirmActionBlock();
      [self refreshUserInfo];
      [self updateButtons];
    }
  }

  _cancelActionBlock = nil;
  _confirmActionBlock = nil;
}

#pragma mark - UITableView Data Source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
  return [_sectionCellLabels count];
}

- (NSInteger)tableView:(UITableView *)tableView
 numberOfRowsInSection:(NSInteger)section {
  return [_sectionCellLabels[section] count];
}

- (NSString *)tableView:(UITableView *)tableView
    titleForHeaderInSection:(NSInteger)section {
  if (section == 0) {
    return @"Sign-in Button Configuration";
  } else if (section == 1) {
    return @"Other Configurations";
  } else if (section == 2) {
      return @"Live Time Configurations";
  } else {
    return nil;
  }
}

- (BOOL)tableView:(UITableView *)tableView
    shouldHighlightRowAtIndexPath:(NSIndexPath *)indexPath {
  // Cells that drill down to other table views should be highlight-able.
  // The other cells contain control elements, so they should not be selectable.
  NSString *label = _sectionCellLabels[indexPath.section][indexPath.row];
  if ([_drillDownCells containsObject:label]) {
    return YES;
  } else {
    return NO;
  }
}

- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath {
  static NSString * const kDrilldownCell = @"DrilldownCell";
  static NSString * const kSwitchCell = @"SwitchCell";
  static NSString * const kSliderCell = @"SliderCell";
  static NSString * const kLiveCell = @"LiveCell";

  NSString *label = _sectionCellLabels[indexPath.section][indexPath.row];
  UITableViewCell *cell;
  NSString *identifier;

  if ([_drillDownCells containsObject:label]) {
    identifier = kDrilldownCell;
  } else if ([_switchCells containsObject:label]) {
    identifier = kSwitchCell;
  } else if ([_sliderCells containsObject:label]) {
    identifier = kSliderCell;
  } else if ([_liveCells containsObject:label]) {
      identifier = kLiveCell;
  }

  cell = [tableView dequeueReusableCellWithIdentifier:identifier];

  if (cell == nil) {
    cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1
                                  reuseIdentifier:identifier];
  }
  // Assign accessibility labels to each cell row.
  cell.accessibilityLabel = label;

  if (identifier == kDrilldownCell) {
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    DataPickerState *dataState = _drilldownCellState[label];
    if (dataState.multipleSelectEnabled) {
      cell.detailTextLabel.text = @"";
    } else {
      cell.detailTextLabel.text = [dataState.selectedCells anyObject];
    }
    cell.accessibilityValue = cell.detailTextLabel.text;
  } else if (identifier == kSwitchCell) {
    UISwitch *toggle = [[UISwitch alloc] initWithFrame:CGRectZero];

    if ([label isEqualToString:kGetUserProfileCellLabel]) {
      [toggle addTarget:self
                    action:@selector(toggleBasicProfile:)
          forControlEvents:UIControlEventValueChanged];
      toggle.on = [GIDSignIn sharedInstance].shouldFetchBasicProfile;
    }

    toggle.accessibilityLabel = [NSString stringWithFormat:@"%@ Switch", cell.accessibilityLabel];
    cell.accessoryView = toggle;
  } else if (identifier == kSliderCell) {

    UISlider *slider = [[UISlider alloc] initWithFrame:CGRectMake(0, 0, 150, 0)];
    slider.minimumValue = [self minimumButtonWidth];
    slider.maximumValue = 268.0;
    slider.value = self.signInButton.frame.size.width;
    slider.enabled = self.signInButton.style != kGIDSignInButtonStyleIconOnly;

    [slider addTarget:self
                  action:@selector(changeSignInButtonWidth:)
        forControlEvents:UIControlEventValueChanged];

    slider.accessibilityIdentifier = [NSString stringWithFormat:@"%@ Slider", label];
    self.signInButtonWidthSlider = slider;
    cell.accessoryView = slider;
    [self.signInButtonWidthSlider sizeToFit];
  } else if (identifier == kLiveCell) {
      NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
      
      if (!indexPath.row) {
          NSString *liveDuration = [defaults stringForKey:@"LiveDuration"];
          if (!liveDuration) {
              liveDuration = @"10";
              [defaults setObject:liveDuration forKey:@"LiveDuration"];
          }
          
          _liveDurationField = [[UITextField alloc] initWithFrame:CGRectMake(CGRectGetWidth(cell.frame) - 70, 0, 70, CGRectGetHeight(cell.frame) - 4)];
          _liveDurationField.borderStyle = UITextBorderStyleBezel;
          _liveDurationField.textAlignment = NSTextAlignmentCenter;
          _liveDurationField.clearButtonMode = UITextFieldViewModeWhileEditing;
          _liveDurationField.text = liveDuration;
          _liveDurationField.keyboardType = UIKeyboardTypePhonePad;
          cell.accessoryView = _liveDurationField;
      } else {
          NSString *postTimeoutInterval = [defaults stringForKey:@"LivePostTimeoutInterval"];
          if (!postTimeoutInterval) {
              postTimeoutInterval = @"10";
              [defaults setObject:postTimeoutInterval forKey:@"LivePostTimeoutInterval"];
          }
          
          _livePostTimeoutIntervalField = [[UITextField alloc] initWithFrame:CGRectMake(CGRectGetWidth(cell.frame) - 70, 0, 70, CGRectGetHeight(cell.frame) - 4)];
          _livePostTimeoutIntervalField.borderStyle = UITextBorderStyleBezel;
          _livePostTimeoutIntervalField.textAlignment = NSTextAlignmentCenter;
          _livePostTimeoutIntervalField.clearButtonMode = UITextFieldViewModeWhileEditing;
          _livePostTimeoutIntervalField.text = postTimeoutInterval;
          _livePostTimeoutIntervalField.keyboardType = UIKeyboardTypePhonePad;
          cell.accessoryView = _livePostTimeoutIntervalField;
      }
  }

  cell.textLabel.text = label;

  return cell;
}

- (void)tableView:(UITableView *)tableView
    didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
  [tableView deselectRowAtIndexPath:indexPath animated:YES];
  UITableViewCell *selectedCell = [tableView cellForRowAtIndexPath:indexPath];
  NSString *label = selectedCell.textLabel.text;

  DataPickerState *dataState = [_drilldownCellState objectForKey:label];
  if (!dataState) {
    return;
  }

  DataPickerViewController *dataPicker =
      [[DataPickerViewController alloc] initWithNibName:nil
                                                 bundle:nil
                                              dataState:dataState];
  dataPicker.navigationItem.title = label;

  // Force the back button title to be 'Back'
  UIBarButtonItem *newBackButton =
      [[UIBarButtonItem alloc] initWithTitle:@"Back"
                                       style:UIBarButtonItemStylePlain
                                      target:nil
                                      action:nil];
  [[self navigationItem] setBackBarButtonItem:newBackButton];
  [self.navigationController pushViewController:dataPicker animated:YES];
}

- (void)startLive {
    [_liveDurationField resignFirstResponder];
    [_livePostTimeoutIntervalField resignFirstResponder];
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSString *liveDuration = _liveDurationField.text;
        if (liveDuration) {
            [[NSUserDefaults standardUserDefaults] setObject:liveDuration forKey:@"LiveDuration"];
        }
        
        NSString *postTimeoutInterval = _livePostTimeoutIntervalField.text;
        if (postTimeoutInterval) {
            [[NSUserDefaults standardUserDefaults] setObject:postTimeoutInterval forKey:@"LivePostTimeoutInterval"];
        }
        
        NSString *authorization = [[[GIDSignIn sharedInstance].currentUser valueForKeyPath:@"authentication.accessToken"] description];
        AppLogInfo(AppLogTagAPP, @"authorization: %@", authorization);
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [self dismissViewControllerAnimated:YES completion:nil];
        });
    });
}

@end
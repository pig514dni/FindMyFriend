//
//  ViewController.m
//  locationMap
//
//  Created by 張峻綸 on 2016/5/25.
//  Copyright © 2016年 張峻綸. All rights reserved.
//

#import "ViewController.h"
#import "MapKit/MapKit.h"
#import "CoreLocation/CoreLocation.h"
@interface ViewController ()<MKMapViewDelegate,CLLocationManagerDelegate>
{
    CLLocationManager *locationManager; //設定地圖狀態
    CLLocation * currentLocation;       //變數為存取目前座標
    BOOL updateSwitch;            //是否上傳的開關
    BOOL followSwitch;            //是否追蹤的開關
    BOOL drawLineSwitch;          //是否畫軌跡的開關
    NSMutableArray *result;                          //SERVER下載下來並轉成JSON的格式
    NSMutableArray *currentLocationArray; //將本身位置存成陣列
    MKPolylineRenderer *Renderer;
}
@property (weak, nonatomic) IBOutlet MKMapView *mainMap;
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    locationManager = [CLLocationManager new];
    currentLocationArray=[NSMutableArray new];
    updateSwitch=true;
    followSwitch=true;
    drawLineSwitch=true;
//    [drawLineSwitch setOn:YES animated:YES];
    if ([locationManager respondsToSelector:@selector(requestAlwaysAuthorization)]) {
        [locationManager requestAlwaysAuthorization];
    }
    //prepare locationManager
    //desiredAccuracy 精確度
    locationManager.desiredAccuracy=kCLLocationAccuracyBest;
    //運用定位的類型
    locationManager.activityType=CLActivityTypeFitness;
    locationManager.delegate=self;
    [locationManager startUpdatingLocation];
    
}
#pragma mark -CLLocationManagerDelegate Methods
-(void)locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray<CLLocation *> *)locations{
    currentLocation=locations.lastObject;
    [currentLocationArray addObject:currentLocation];
    // Make the region change just once
    [_mainMap removeAnnotations:[_mainMap annotations]];
    static dispatch_once_t changeRegionOnceToken;
    dispatch_once(&changeRegionOnceToken, ^{
        MKCoordinateRegion  region;
        region.center=currentLocation.coordinate;
        //螢幕畫面距離中心點的距離,設定為經緯度0.1度
        //蘋果會找一個最近最適合的經度或緯度顯示
        region.span.latitudeDelta=0.01;
        region.span.longitudeDelta=0.01;
        [_mainMap setRegion:region animated:YES];
    });
    [self myAnnotation ];
    
    [self loadFromServer];
    [self friendsAnnotation];
    if (updateSwitch==true) {
        [self updateToServer];
    }
    if (followSwitch==true) {
        [self followSelf];
    }
    if (drawLineSwitch==true) {
        [self drawLine];
    }else{
        currentLocationArray=[NSMutableArray new];
    }
    
}

#pragma mark -選擇是否上傳座標到SERVER
- (IBAction)SelectUpdateToServer:(UISwitch *)sender {
    if (sender.on) {
        updateSwitch=true;
    }else{
        updateSwitch=false;
    }
}
#pragma mark -上傳座標位置到SERVER
-(void)updateToServer{
    NSString *urlString = [NSString stringWithFormat:@"http://class.softarts.cc/FindMyFriends/updateUserLocation.php?GroupName=ap102&UserName=chunlun&Lat=%.6f&Lon=%.6f",currentLocation.coordinate.latitude,currentLocation.coordinate.longitude];
    NSURL * url=[NSURL URLWithString:urlString];
    
    //Prepare NSURLSession
    NSURLSessionConfiguration * config=[NSURLSessionConfiguration defaultSessionConfiguration];
    NSURLSession * session=[NSURLSession sessionWithConfiguration:config];
    NSURLSessionDataTask *task=[session dataTaskWithURL:url completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        if(error){
            NSLog(@"Error");
            return ;
        }
    }];
    [task resume];
}
#pragma mark -選擇是否追蹤自己
- (IBAction)SelectFellowSelf:(UISwitch *)sender {
    
    if (sender.on) {
        followSwitch=true;
    }else{
        followSwitch=false;
    }
}
#pragma mark -追蹤自己
-(void)followSelf{
    MKCoordinateRegion  region;
    region.center=currentLocation.coordinate;
    region.span.latitudeDelta=0.01;
    region.span.longitudeDelta=0.01;
    [_mainMap setRegion:region animated:YES];
}
#pragma mark -選擇是否畫線
- (IBAction)SelectDrawLine:(UISwitch *)sender {
    if (sender.on) {
        drawLineSwitch=true;
        [_mainMap removeOverlays:[_mainMap overlays]];
    }else{
        drawLineSwitch=false;
    }
}
#pragma mark -設定軌跡
-(void)drawLine
{
    // create an array of coordinates from allPins
    CLLocationCoordinate2D coordinates[currentLocationArray.count];
    int i = 0;
    for (CLLocation *currentPin in currentLocationArray) {
        coordinates[i] = currentPin.coordinate;
        i++;
    }
    // create a polyline with all cooridnates
    MKPolyline *polyline = [MKPolyline polylineWithCoordinates:coordinates count:currentLocationArray.count];
    
    // create an MKPolylineView and add it to the map view
    Renderer= [[MKPolylineRenderer alloc]initWithPolyline:polyline];
    Renderer.strokeColor=[UIColor blueColor];
    Renderer.lineWidth=5;
    [_mainMap addOverlay:polyline];
}
#pragma mark -畫軌跡
-(MKOverlayRenderer *)mapView:(MKMapView *)mapView rendererForOverlay:(id<MKOverlay>)overlay
{
    return Renderer;
}
#pragma mark -製作自己的大頭針
-(void)myAnnotation{
    CLLocationCoordinate2D  annotationCoordinate=currentLocation.coordinate;
    MKPointAnnotation * annotation =[MKPointAnnotation new];
    annotation.coordinate=annotationCoordinate;
    annotation.title=@"chunlun";
    [_mainMap addAnnotation:annotation];
}
#pragma mark -製作朋友得大頭針
-(void)friendsAnnotation{
    NSArray * array=[[NSArray alloc]initWithArray:result];
    for (int i=0; i<array.count; i++) {
        NSDictionary * tmpDictionary=array[i];
        NSString * friendsLat=[tmpDictionary objectForKey:@"lat"];
        NSString * friendsLon = [tmpDictionary objectForKey:@"lon"];
        NSString *friendsName=[tmpDictionary objectForKey:@"friendName"];
        CLLocationCoordinate2D friendsCoordinate;
        friendsCoordinate.latitude=friendsLat.floatValue;
        friendsCoordinate.longitude=friendsLon.floatValue;
        MKPointAnnotation * friendsAnnotation= [MKPointAnnotation new];
        friendsAnnotation.coordinate=friendsCoordinate;
        friendsAnnotation.title=friendsName;
        if ([friendsName isEqualToString:@"chunlun"]) {
        }else{
            [_mainMap addAnnotation:friendsAnnotation];
        }
    }
}
#pragma mark -下載資料並轉為JSON
-(void)loadFromServer{
    NSString * urlstring =[NSString stringWithFormat:@"http://class.softarts.cc/FindMyFriends/queryFriendLocations.php?GroupName=ap102"];
    NSURL * url=[NSURL URLWithString:urlstring];
    NSURLSessionConfiguration * config=[NSURLSessionConfiguration defaultSessionConfiguration];
    NSURLSession * session = [NSURLSession sessionWithConfiguration:config];
    NSURLSessionDataTask * task =[session dataTaskWithURL:url completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        if (error) {
            NSLog(@"Error");
        }
//        NSString * content=[[NSString alloc]initWithData:data encoding:NSUTF8StringEncoding];
//        NSLog(@"content:%@",content);
        NSDictionary * resultDictionary=[NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableContainers error:&error];
        result=[[NSMutableArray alloc]initWithArray:[resultDictionary objectForKey:@"friends"]];
    }];
    [task resume];
}
- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end

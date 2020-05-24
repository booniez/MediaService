//
//  ViewController.m
//  MediaService
//
//  Created by chenjiannan on 2018/6/22.
//  Copyright © 2018年 chenjiannan. All rights reserved.
//

#import "ViewController.h"
#import "VPVideoStreamPlayLayer.h"
#import "VEVideoEncoder.h"
#import "H264Decoder.h"
#import "VCVideoCapturer.h"
#import "MetalPlayer.h"

#define USED_METAL

@interface ViewController () <H264DecoderDelegate, VEVideoEncoderDelegate, VCVideoCapturerDelegate, GCDAsyncSocketDelegate>

/** 视频流播放器 */
#ifdef USED_METAL
@property (nonatomic, strong) MetalPlayer *playLayer;
@property (nonatomic, strong) UIImageView *img;
@property (nonatomic, strong) UIImage *row_img;
@property (nonatomic, strong) NSData *row_img_data;
@property (nonatomic, strong) NSMutableData *buffer;
#else
@property (nonatomic, strong) VPVideoStreamPlayLayer *playLayer;
#endif
/** 解码播放视图 */
@property (nonatomic, strong) AVCaptureVideoPreviewLayer *recordLayer;

/** H264解码器 */
@property (nonatomic, strong) H264Decoder *h264Decoder;
/** 视频采集 */
@property (nonatomic, strong) VCVideoCapturer *videoCapture;
/** 视频编码器 */
@property (nonatomic, strong) VEVideoEncoder *videoEncoder;

@end

@implementation ViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor whiteColor];
    
    // 初始化视频采集
    VCVideoCapturerParam *param = [[VCVideoCapturerParam alloc] init];
    param.sessionPreset = AVCaptureSessionPreset1280x720;
    
    self.videoCapture = [[VCVideoCapturer alloc] initWithCaptureParam:param error:nil];
    self.videoCapture.delegate = self;
    
    // 初始化并开启视频编码
    VEVideoEncoderParam *encodeParam = [[VEVideoEncoderParam alloc] init];
    encodeParam.encodeWidth = 180;
    encodeParam.encodeHeight = 320;
    encodeParam.bitRate = 512 * 1024;
    _videoEncoder = [[VEVideoEncoder alloc] initWithParam:encodeParam];
    _videoEncoder.delegate = self;
    [_videoEncoder startVideoEncode];
    
    // 初始化视频解码
    self.h264Decoder = [[H264Decoder alloc] init];
    self.h264Decoder.delegate = self;
    
    
    CGFloat layerMargin = 15;
    CGFloat layerW = (self.view.frame.size.width - 3 * layerMargin) * 0.5;
    CGFloat layerH = layerW * 16 / 9.00;
    CGFloat layerY = 120;
    
    // 初始化视频采集的预览画面
    self.recordLayer = self.videoCapture.videoPreviewLayer;
    self.recordLayer.frame = CGRectMake(layerMargin, layerY, layerW, layerH);

    // 初始化视频编码解码后的播放画面
#ifdef USED_METAL
    self.playLayer = [[MetalPlayer alloc] initWithFrame:CGRectMake(layerMargin * 2 + layerW, layerY, layerW, layerH)];
#else
    self.playLayer = [[VPVideoStreamPlayLayer alloc] initWithFrame:CGRectMake(layerMargin * 2 + layerW, layerY, layerW, layerH)];
#endif
    self.playLayer.backgroundColor = [UIColor blackColor].CGColor;
    
    CGFloat buttonW = self.view.frame.size.width * 0.4;
    CGFloat buttonH = 40;
    CGFloat buttonMargin = (self.view.frame.size.width - buttonW * 2) / 3.0;
    CGFloat buttonY = 60;
    
    UIButton *cameraButton = [[UIButton alloc] initWithFrame:CGRectMake(buttonMargin, buttonY, buttonW, buttonH)];
    [cameraButton setTitle:@"开启/关闭 摄像头" forState:UIControlStateNormal];
    [cameraButton setBackgroundColor:[UIColor lightGrayColor]];
    [cameraButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [cameraButton addTarget:self action:@selector(cameraButtonAction:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:cameraButton];
    
    UIButton *revertCameraButton = [[UIButton alloc] initWithFrame:CGRectMake(buttonMargin * 2 + buttonW, buttonY, buttonW, buttonH)];
    [revertCameraButton setTitle:@"切换摄像头" forState:UIControlStateNormal];
    [revertCameraButton setBackgroundColor:[UIColor lightGrayColor]];
    [revertCameraButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [revertCameraButton addTarget:self action:@selector(revertCameraButtonAction:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:revertCameraButton];
    [self configSocket];

    _img = [[UIImageView alloc]initWithFrame:CGRectMake(buttonMargin,buttonY+60, 400, 300)];
    _buffer = [[NSMutableData alloc]init];
//    [_img setBackgroundColor:[UIColor redColor]];
    [self.view addSubview:_img];

}

- (void)configSocket {
    socketQueue = dispatch_queue_create("socketQueue", NULL);
    
    listenSocket = [[GCDAsyncSocket alloc] initWithDelegate:self delegateQueue:socketQueue];
    
    int port = 2345;
    NSError *error = nil;
    if(![listenSocket acceptOnPort:port error:&error])
    {
        NSLog(@"error starting server %@",error);
        return;
    } else {
        NSLog(@"starting server");
    }
}

- (void)cameraButtonAction:(UIButton *)button
{
    button.selected = !button.selected;
    if (button.selected)
    {
        [self.videoCapture startCapture];
        [self.view.layer addSublayer:self.recordLayer];
        [self.view.layer addSublayer:self.playLayer];
    }
    else
    {
        [self.videoCapture stopCapture];
        [self.videoCapture.videoPreviewLayer removeFromSuperlayer];
        [self.playLayer removeFromSuperlayer];
    }
}

- (void)revertCameraButtonAction:(UIButton *)button
{
    [self.videoCapture reverseCamera];
}



#pragma mark - 视频采集回调
- (void)videoCaptureOutputDataCallback:(CMSampleBufferRef)sampleBuffer
{
    [self.videoEncoder videoEncodeInputData:sampleBuffer forceKeyFrame:NO];
}

#pragma mark - H264编码回调
- (void)videoEncodeOutputDataCallback:(NSData *)data isKeyFrame:(BOOL)isKeyFrame
{
    
//    NSString *str = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
//    if (str != nil) {
//        str = [NSString stringWithFormat:@"%@", "|"];
//        NSData *da = [str dataUsingEncoding:NSUTF8StringEncoding];
//    NSDictionary
//        [connectSocket writeData:data withTimeout:-1 tag:0];
//    NSString *msg = @"|#|";
//    NSData *msgData = [msg dataUsingEncoding:NSUTF8StringEncoding];
//    [connectSocket writeData:msgData withTimeout:-1 tag:0];
//        NSLog(@"上报");
//    }
//    [self.h264Decoder decodeNaluData:data];
//    [connectSocket readDataWithTimeout:-1 tag:0];
}

#pragma mark - H264解码回调
- (void)videoDecodeOutputDataCallback:(CVImageBufferRef)imageBuffer
{
    NSLog(@"解码回调");
    [self.playLayer inputPixelBuffer:imageBuffer];
    CVPixelBufferRelease(imageBuffer);
}

#pragma mark - Socket 回调
- (void)socket:(GCDAsyncSocket *)sock didAcceptNewSocket:(GCDAsyncSocket *)newSocket
{
    // This method is executed on the socketQueue (not the main thread)
    connectSocket = newSocket;
    [newSocket readDataWithTimeout: -1 tag: 0];

    
}

- (void)socketDidDisconnect:(GCDAsyncSocket *)sock withError:(NSError *)err
{
    if (sock != listenSocket)
    {
        NSLog(@"client disconnected");
    }
}

- (void)socket:(GCDAsyncSocket *)sock didReadData:(NSData *)data withTag:(long)tag{
    [connectSocket readDataWithTimeout:-1 tag:0];
    NSMutableData *tmp_data = NULL;
    NSMutableData *input_data = [data copy];

    NSString *end_flag = @"|#|";
    end_flag = [NSString stringWithFormat:@"%@",[end_flag dataUsingEncoding: NSUTF8StringEncoding]];
    end_flag = [end_flag substringToIndex:end_flag.length-1];
    end_flag = [end_flag substringFromIndex:1];
    end_flag = [end_flag componentsSeparatedByString:@"="][2];
    end_flag = [end_flag substringFromIndex:3];

    NSString *str_data=[NSString stringWithFormat:@"%@",data];
    str_data=[str_data stringByReplacingOccurrencesOfString:@" " withString:@""];
    str_data=[str_data lowercaseString];
    str_data=[str_data substringToIndex:str_data.length-1];
    str_data=[str_data substringFromIndex:1];
    str_data=[str_data componentsSeparatedByString:@"="][2];
    str_data=[str_data substringFromIndex:2];

    char *the_data = (char *)malloc(sizeof(char) * data.length);
    the_data = (char *)data.bytes;


    if ([str_data containsString:end_flag]) {
        char *location = the_data;
        int lenth = 0;

        while (location != '\0' && location != NULL) {
            if (*location == '|' && *(location+1) == '#' && *(location+2) == '|') {
                break;
            }
            lenth += 1;
            location ++;
        }

        if (sizeof(the_data) == 3) {
            tmp_data = [_buffer copy];
            [_buffer setData:[[NSData alloc]init]];

        }

        [_buffer appendData:[input_data subdataWithRange:NSMakeRange(0, lenth)]];
        tmp_data = [_buffer copy];
        if (input_data.length - lenth == 3){
             [_buffer setData:[[NSData alloc]init]];
        }else{
            _buffer = [[input_data subdataWithRange:NSMakeRange(lenth + 3, data.length - lenth - 3)] copy];
        }
    }else{
        [_buffer appendData:data];
        tmp_data = NULL;
    }

    if (tmp_data != NULL) {
        dispatch_async(dispatch_get_main_queue(), ^{
            int flag = 0;
            @try {
                [self->_img setImage:[UIImage imageWithData:tmp_data]];
            } @catch (NSException *exception) {
                flag = 1;
                NSLog(@"error");
            } @finally {
                if (flag) {
                    NSLog(@"error2");
                }
            }

        });
    }

//    [self.h264Decoder decodeNaluData:data];
}

@end

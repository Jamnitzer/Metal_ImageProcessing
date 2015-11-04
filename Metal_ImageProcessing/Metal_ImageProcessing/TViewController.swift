//------------------------------------------------------------------------------
//  Derived from Apple's WWDC example "MetalImageProcessing"
//  Created by Jim Wrenholt on 12/6/14.
//------------------------------------------------------------------------------
import UIKit

//-----------------------------------------------------------------------------
@objc protocol TViewControllerDelegate
{
    //------------------------------------------------------
    // Note this method is called from the
    // thread the main game loop is run
    //------------------------------------------------------
    func update(controller:TViewController)

    //------------------------------------------------------
    // called whenever the main game loop is paused,
    // such as when the app is backgrounded
    //------------------------------------------------------
    func viewController(controller:TViewController, willPause:Bool)
}
//-----------------------------------------------------------------------------
class TViewController: UIViewController
{
    @IBOutlet weak var delegate: TViewControllerDelegate!
    //------------------------------------------------------
    // What vsync refresh interval to fire at.
    // (Sets CADisplayLink frameinterval property) set to 1 by default,
    // which is the CADisplayLink default setting (60 FPS).
    // Setting to 2, will cause gameloop to trigger every
    // other vsync (throttling to 30 FPS)
    //------------------------------------------------------
    var interval:Int = 1

    // Used to pause and resume the controller.
    var paused:Bool = false

    // app control
    var timer: CADisplayLink! = nil

    // boolean to determine if the first draw has occured
    var _firstDrawOccurred:Bool = false

    //the time interval from the last draw
    var _timeSinceLastDraw: Double = 0

    var _timeSinceLastDrawPreviousTime:Double = 0

    // pause/resume
    var _gameLoopPaused:Bool = false

    // our renderer instance
    var renderer:TRenderer?
    
    //-------------------------------------------------------------------------
    deinit
    {
        NSNotificationCenter.defaultCenter().removeObserver(
            self,
            name: UIApplicationDidEnterBackgroundNotification,
            object:nil)

        NSNotificationCenter.defaultCenter().removeObserver(
            self,
            name: UIApplicationWillEnterForegroundNotification,
            object: nil)

        if (timer != nil)
        {
            stopGameLoop()
        }
    }
    //-------------------------------------------------------------------------
    func initCommon()
    {
        renderer = TRenderer()
        self.delegate = renderer!

        //--------------------------------------------------
        // Register notifications to start/stop drawing as
        // this app moves into the background
        //--------------------------------------------------
       NSNotificationCenter.defaultCenter().addObserver(
            self,
            selector: Selector("didEnterBackground"),
            name: UIApplicationDidEnterBackgroundNotification,
            object:nil)

        NSNotificationCenter.defaultCenter().addObserver(
            self,
            selector: Selector("willEnterForeground"),
            name: UIApplicationWillEnterForegroundNotification,
            object: nil)

        interval = 1
    }
    //-------------------------------------------------------------------------
//    override init()
//    {
//        super.init()
//        initCommon()
//    }
    //-------------------------------------------------------------------------
    // called when loaded from nib
    //-------------------------------------------------------------------------
    override init(nibName: String?, bundle nibBundle: NSBundle?)
    {
        super.init(nibName: nibName, bundle: nibBundle)
        initCommon()
    }
    //-------------------------------------------------------------------------
    required init(coder aDecoder: NSCoder)
    {
        super.init(coder:aDecoder)!
        initCommon()
    }
    //-------------------------------------------------------------------------
    override func viewDidLoad()
    {
        super.viewDidLoad()

        let renderView = self.view as! TView
        renderView.delegate = renderer
        // load all renderer assets before starting game loop
        renderer!.configure(renderView)
    }
    //-------------------------------------------------------------------------
    func dispatchGameLoop()
    {
       //------------------------------------------------------------
        // create a game loop timer using a display link
        //------------------------------------------------------------
        timer = CADisplayLink(target: self, selector: Selector("gameloop:"))
        timer!.frameInterval = interval
        timer!.addToRunLoop(NSRunLoop.mainRunLoop(), forMode: NSDefaultRunLoopMode)
    }
    //-------------------------------------------------------------------------
    // the main game loop called by the timer above
    //-------------------------------------------------------------------------
    func gameloop(displayLink: CADisplayLink)
    {
        //-------------------------------------------------------------------
        // tell our delegate to update itself here.
        //-------------------------------------------------------------------
        delegate.update(self)

        if (!_firstDrawOccurred)
        {
            //---------------------------------------------------------------
            // set up timing data for display since this is the 
            // first time through this loop
            //---------------------------------------------------------------
            _timeSinceLastDraw             = 0.0
            _timeSinceLastDrawPreviousTime = CACurrentMediaTime()
            _firstDrawOccurred             = true
        }
        else
        {
            //---------------------------------------------------------------
            // figure out the time since we last we drew
            //---------------------------------------------------------------
            let currentTime:CFTimeInterval = CACurrentMediaTime()
            _timeSinceLastDraw = currentTime - _timeSinceLastDrawPreviousTime
            //---------------------------------------------------------------
            // keep track of the time interval between draws
            //---------------------------------------------------------------
            _timeSinceLastDrawPreviousTime = currentTime
        }
        //-------------------------------------------------------------------
        // display (render)
        //-------------------------------------------------------------------
        assert(view is TView)  // isKindOfClass

        //-------------------------------------------------------------------
        // call the display method directly on the render view
        // (setNeedsDisplay: has been disabled in the renderview by default)
        //-------------------------------------------------------------------
        let myview:TView = self.view as! TView
        myview.display()
    }
    //-------------------------------------------------------------------------
    func stopGameLoop()
    {
        //-------------------------------------------------------------------
        // use invalidates the main game loop.
        // when the app is set to terminate
        //-------------------------------------------------------------------
        if ( timer != nil)
        {
            timer!.invalidate()
        }
    }
    //-------------------------------------------------------------------------
    func set_Paused(pause:Bool)
    {
        if (_gameLoopPaused == true)
        {
            return
        }
        if (timer != nil)
        {
            //-------------------------------------------------
            // inform the delegate we are about to pause
            //-------------------------------------------------
            delegate.viewController(self, willPause:pause)
            if (pause == true)
            {
                _gameLoopPaused = true
                timer!.paused  = true
                //-------------------------------------------------
                // ask the view to release textures until its resumed
                //-------------------------------------------------
                let myview:TView = self.view as! TView
                myview.releaseTextures()
            }
            else
            {
                _gameLoopPaused = false
                timer!.paused  = false
            }
        }
    }
    //-------------------------------------------------------------------------
    func isPaused() -> Bool
    {
        return _gameLoopPaused
    }
    //-------------------------------------------------------------------------
    func didEnterBackground(notification:NSNotification)
    {
        self.set_Paused(true)
    }
    //-------------------------------------------------------------------------
    func willEnterForeground(notification:NSNotification)
    {
        self.set_Paused(false)
    }
    //-------------------------------------------------------------------------
    override func viewWillAppear(animated:Bool)
    {
        super.viewWillAppear(animated)
        self.dispatchGameLoop()  // run the game loop
    }
    //-------------------------------------------------------------------------
    override func viewWillDisappear(animated:Bool)
    {
        super.viewWillDisappear(animated)
        self.stopGameLoop()  // end the gameloop
    }
    //-------------------------------------------------------------------------
}
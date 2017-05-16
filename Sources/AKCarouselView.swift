//
//  AKCarouselView.swift
//  CLCarouselView
//
//  Created by liuchang on 2016/11/8.
//  Copyright © 2016年 com.unknown. All rights reserved.
//

import UIKit
enum AKCarouselPageControlDisplayModel {
    //this is defualt.if datasource.count > 1 show pageControl,else hidden
    case auto
    case alwaysShow
    case alwaysHidden
}


//MARK:-
class AKCarouselView: UIView,UIScrollViewDelegate {
    var contentScale:CGFloat = 1
    var contentHorizonelMargin : CGFloat = 0
    var contentSize:CGSize?
    var currentIndex = 0
    var autoScrollInterval:TimeInterval = 0
    var pageControlDisplayModel = AKCarouselPageControlDisplayModel.auto
    weak var pageControl : AKCarouselPageControl?{
        willSet(newView){
            self.pageControl?.removeFromSuperview()
            if (newView != nil) {
                self.addSubview(newView!)
            }
        }
    }
    weak var extraView : UIView?{
        willSet(newView){
            self.extraView?.removeFromSuperview()
            if let newView = newView{
                self.addSubview(newView)
            }
        }
    }

    var dataSourceProvider : ((AKCarouselView) -> [AnyObject])!
    var contentViewProvider : ((AKCarouselView, Int) -> UIView)!

    var onContentViewSelected : ((_: AKCarouselView, _:Int, _:UIView)->Void)?
    var onContentViewIndexChange : ((AKCarouselView, Int) -> Void)?
    var resizeExtraView:((AKCarouselView,UIView) -> Void)?

    private var contentViewWidth:CGFloat{
        get{
            return self.adjustedContentSize.width + self.contentHorizonelMargin
        }
    }
    private var adjustedContentSize :CGSize{
        return self.contentSize ?? self.bounds.size
    }
    private var originalViewCount = 0
    private var contentViewCount = 0
    private var displayRange = NSRange(location: 0,length: 0)
    private weak var scrollView:UIScrollView!
    private var cacheContentViews = [Int:UIView]()
    private var reuseableContentViews = [UIView]()
    private var autoScrollTimer : Timer?
    private var autoScrollIndex = 0



    //MARK:overwite

    init(frame: CGRect
        ,contentViewSize:CGSize? = nil
        ,dataSourceProvider:@escaping ((_: AKCarouselView) -> [AnyObject])
        ,contentViewProvider:@escaping ((_: AKCarouselView, _:Int) -> UIView)) {
        super.init(frame: frame)
        setup()
        self.contentSize = contentViewSize
        self.dataSourceProvider = dataSourceProvider
        self.contentViewProvider = contentViewProvider
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        setup()
    }

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let view = super.hitTest(point, with: event)
        if view == self{
            return self.scrollView
        }else{
            return view
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let oldScrollViewFrame = self.scrollView.frame;
        self.layoutScrollView()
        if oldScrollViewFrame != self.scrollView.frame {
            self.reloadData()
        }

        if let pageControl = self.pageControl {
            pageControl.frame = pageControl.fitFrameInSuperView(self.bounds)
        }
        if let extraView = self.extraView,let resizeBlock = self.resizeExtraView{
            resizeBlock(self,extraView)
        }

    }

    override func willMove(toSuperview newSuperview: UIView?) {
        super.willMove(toSuperview: newSuperview)
        if (newSuperview == nil) {
            self.stopAutoScroll()
        }
    }


    //MARK:private methods

    private func setup() {
        let notificationCenter = NotificationCenter.default
        notificationCenter.addObserver(self, selector: #selector(notificationHandler(_:)), name: NSNotification.Name.UIApplicationDidBecomeActive, object: nil)
        notificationCenter.addObserver(self, selector: #selector(notificationHandler(_:)), name: NSNotification.Name.UIApplicationDidEnterBackground, object: nil)
        self.setupViews()
    }

    private func setupViews(){
        let scrollView = UIScrollView()
        scrollView.isScrollEnabled = true
        scrollView.isPagingEnabled = true
        scrollView.clipsToBounds = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.bounces = false
        scrollView.alwaysBounceVertical = false
        scrollView.alwaysBounceHorizontal = false
        scrollView.backgroundColor = UIColor.clear
        scrollView.delegate = self
        let tap = UITapGestureRecognizer(target: self, action: #selector(tapHandler(_:)))
        scrollView.addGestureRecognizer(tap)

        self.addSubview(scrollView)
        self.scrollView = scrollView

    }

    @objc private func tapHandler(_ tapGesture:UITapGestureRecognizer){
        if(tapGesture.view == self.scrollView
            && tapGesture.state == .ended
            && self.contentViewWidth > 0){

            if let onContentViewSelected = self.onContentViewSelected{
                let point = tapGesture.location(in: tapGesture.view)
                let viewIndex = Int(floor(point.x / self.contentViewWidth))
                let dataSourceIndex = viewIndex % self.originalViewCount
                let view = self.cacheContentViews[viewIndex]!
                onContentViewSelected(self, dataSourceIndex, view);
            }

        }
    }
    
    private func layoutScrollView(){
        let viewW = self.frame.size.width;
        let contentViewH = self.adjustedContentSize.height
        let scrollViewW = self.contentViewWidth;
        let scrollViewY = (self.frame.size.height - contentViewH) / 2;
        self.scrollView.frame = CGRect(x:(viewW - scrollViewW) / 2, y:scrollViewY, width:scrollViewW, height:contentViewH);
    }

    private func startAutoScroll(){
        if (self.autoScrollTimer == nil
            && self.autoScrollInterval > 0
            && self.originalViewCount > 1) {
            let timer = Timer(timeInterval: self.autoScrollInterval, target: self, selector: #selector(doAutoScroll), userInfo: nil, repeats: true)
            RunLoop.current.add(timer, forMode: .commonModes)
            self.autoScrollTimer = timer
        }
    }

    private func stopAutoScroll(){
        self.autoScrollTimer?.invalidate()
        self.autoScrollTimer = nil;
    }

    @objc private func doAutoScroll(){
        self.autoScrollIndex += 1
        self.scrollView.setContentOffset(CGPoint(x:self.contentViewWidth * CGFloat(self.autoScrollIndex),y:0), animated: true)
    }

    private func setContentView(offset:CGPoint){
        let scrollFrame = self.scrollView.frame
        let bounds = self.bounds
        let startPoint = CGPoint(x: offset.x - scrollFrame.origin.x, y: offset.y - scrollFrame.origin.y)
        let endPoint = CGPoint(x:startPoint.x + bounds.size.width, y:startPoint.y + bounds.size.height)

        var startIndex = 0
        var endIndex = self.contentViewCount - 1
        let contentViewWidth = self.contentViewWidth
        for i in 0..<self.contentViewCount {
            if (contentViewWidth * CGFloat(i + 1) > startPoint.x) {
                startIndex = i;
                break;
            }
        }

        for i in stride(from: self.contentViewCount, through: startIndex, by: -1){
            if (contentViewWidth * CGFloat(i) < endPoint.x) {
                endIndex = i;
                break;
            }
        }

        self.displayRange = NSRange(location: startIndex, length: endIndex - startIndex + 1)

        for i in 0..<startIndex {
            self.removeContentView(i)
        }
        for i in endIndex+1..<self.contentViewCount {
            self.removeContentView(i)
        }
        for i in startIndex...endIndex {
            self.addContentView(i)
        }
    }

    private func refreshVisiblePageAppearance(){
        if (self.contentScale >= 1.0 || self.contentScale <= 0.0) {return}
        let offset = self.scrollView.contentOffset.x
        let contentWidth = self.contentViewWidth
        for i in self.displayRange.location..<self.displayRange.location + self.displayRange.length {
            if let page = self.cacheContentViews[i]{
                let originX = page.frame.origin.x;
                let delta = fabs(originX - offset);
                let originPageFrame = CGRect(x:contentWidth * CGFloat(i), y:0, width:contentWidth, height:self.adjustedContentSize.height);
                var inset = contentWidth * (1 - self.contentScale) * 0.5;
                if (delta < contentWidth) {
                    inset *= (delta / contentWidth);
                }
                page.frame = UIEdgeInsetsInsetRect(originPageFrame, UIEdgeInsetsMake(inset, inset, inset, inset));
            }
        }
    }

    private func removeContentView(_ index:Int){
        if let view = self.cacheContentViews[index]{
            self.cacheContentViews.removeValue(forKey: index)
            self.reuseableContentViews.append(view)
            if (view.superview != nil) {
                view.removeFromSuperview()
            }
        }
    }

    private func addContentView(_ index:Int){
        if (index < 0 || index >= self.contentViewCount ) {return}
        var view = self.cacheContentViews[index]
        if (view == nil) {
            view = self.contentViewProvider!(self,index % self.originalViewCount)
            self.cacheContentViews[index] = view
            if (view?.superview != self.scrollView) {
                self.scrollView.addSubview(view!)
            }
            let margin = self.contentHorizonelMargin / 2;
            view?.frame = CGRect(x:margin + CGFloat(index) * (self.contentViewWidth), y:0, width:self.adjustedContentSize.width, height:self.adjustedContentSize.height);
        }
    }

    @objc private func notificationHandler(_ notification:NSNotification){
        let notifcationName = notification.name;
        if (notifcationName == NSNotification.Name.UIApplicationDidEnterBackground) {
            self.stopAutoScroll()
        }else if (notifcationName == NSNotification.Name.UIApplicationDidBecomeActive){
            self.startAutoScroll()
        }
    }





    //MARK:public methods
    func scrollTo(_ index:Int) {
        if (index < self.contentViewCount) {
            self.stopAutoScroll()
            self.autoScrollIndex = index + self.originalViewCount;
            self.scrollView.setContentOffset(CGPoint(x:self.contentViewWidth * CGFloat(index + self.originalViewCount),y:0), animated: true)
            self.setContentView(offset: self.scrollView.contentOffset)
            self.refreshVisiblePageAppearance()
            self.startAutoScroll()
        }
    }

    func reloadData() {
        self.stopAutoScroll()
        for subView in self.scrollView.subviews {
            subView.removeFromSuperview()
        }
        self.cacheContentViews.removeAll()
        self.reuseableContentViews.removeAll()
        self.displayRange = NSRange(location: 0, length: 0)
        self.originalViewCount = 0
        if let dataSourceProvider = self.dataSourceProvider {
            self.originalViewCount = dataSourceProvider(self).count
            self.contentViewCount = self.originalViewCount == 1 ? 1 : self.originalViewCount * 3
        }
        self.pageControl?.indicatorCount = self.originalViewCount

        if (self.pageControlDisplayModel == .auto) {
            self.pageControl?.isHidden = self.originalViewCount == 0
        }else if(self.pageControlDisplayModel == .alwaysShow){
            self.pageControl?.isHidden = false
        }else{
            self.pageControl?.isHidden = true
        }
        self.scrollView.contentSize = CGSize(width: self.contentViewWidth * CGFloat(self.contentViewCount), height: 1)

        if (self.originalViewCount > 1) {
            self.scrollView.contentOffset = CGPoint(x: self.contentViewWidth * CGFloat(self.originalViewCount), y: 0)
        }
        self.autoScrollIndex = self.originalViewCount
        self.setContentView(offset: self.scrollView.contentOffset)
        self.refreshVisiblePageAppearance()
        if let onContentViewIndexChange = self.onContentViewIndexChange , self.originalViewCount > 0 {
            onContentViewIndexChange(self,0)
        }
        self.startAutoScroll()

    }

    func dequeueReuseView() -> UIView? {
        return self.reuseableContentViews.popLast()
    }

    //MARK: scrollViewDelegate
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        if (self.originalViewCount < 2) {return}
        let contentWidth = self.contentViewWidth
        let offsetIndex = scrollView.contentOffset.x / contentWidth
        let pageIndex = lroundf(Float(offsetIndex)) % self.originalViewCount

        if (offsetIndex >=  CGFloat(2 * self.originalViewCount)) {
            self.scrollView.setContentOffset(CGPoint(x:contentWidth * CGFloat(self.originalViewCount),y:0), animated: false)
            self.autoScrollIndex = self.originalViewCount
        }else if(offsetIndex <= CGFloat(self.originalViewCount - 1)){
            self.scrollView.setContentOffset(CGPoint(x:CGFloat(2 * self.originalViewCount - 1) * contentWidth,y:0), animated: false)
            self.autoScrollIndex = 2 * self.originalViewCount;
        }
        self.setContentView(offset: scrollView.contentOffset)
        self.refreshVisiblePageAppearance()
        if (self.currentIndex != pageIndex) {
            self.currentIndex = pageIndex
            self.pageControl?.currentSelectedIndex = pageIndex
            if let onContentViewIndexChange = self.onContentViewIndexChange {
                onContentViewIndexChange(self,pageIndex)
            }
        }
    }

    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        self.stopAutoScroll()
    }

    func scrollViewWillEndDragging(_ scrollView: UIScrollView, withVelocity velocity: CGPoint, targetContentOffset: UnsafeMutablePointer<CGPoint>) {
        if (self.originalViewCount > 1 && self.autoScrollInterval > 0) {
            self.startAutoScroll()
            let contentWidth = self.contentViewWidth
            let num = Int(floor(scrollView.contentOffset.x / contentWidth));
            if (self.autoScrollIndex == num) {
                self.autoScrollIndex = num + 1;
            } else {
                self.autoScrollIndex = num;
            }
        }
    }
}

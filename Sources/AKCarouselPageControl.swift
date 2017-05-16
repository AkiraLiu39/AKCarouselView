//
//  AKCarouselPageControl.swift
//  CLCarouselView
//
//  Created by liuchang on 2016/11/8.
//  Copyright © 2016年 com.unknown. All rights reserved.
//

import UIKit
public enum AKCarouselPageControlViewType {
    case normal
    case selected
}
public class AKCarouselPageControl: UIView {
    public var indicatorCount = 0{
        didSet{
            self.setupIndicator(self.indicatorCount)
        }
    }
    public var currentSelectedIndex :Int{
        get{
            return self.selectedIndex
        }
        set{
            changeSelectedIndicator(newValue)
        }
    }
    public var onIndicatorClicked : ((_ pageControl: AKCarouselPageControl, _ index:Int, _ indecator:UIView)->Void)?

    private var selectedIndex = 0;
    private var indicatorHorizonMargin:CGFloat = 0
    private var indicatorSize = CGSize.zero
    private var indicatorReference = [Int:UIView]()
    private weak var selectedIndicator:UIView!

    private var adjustFrameClosures:((_ superViewBounds:CGRect,_ selfFitSize:CGSize)->CGRect)!
    private var indicatorViewProvider:((_ pageControl: AKCarouselPageControl, _ viewType: AKCarouselPageControlViewType)->UIView)!

    public init(
        indicatorProvider:@escaping ((_ pageControl: AKCarouselPageControl, _ viewType: AKCarouselPageControlViewType)->UIView)
        ,adjustFrameInSuperView:@escaping ((_ superViewBounds:CGRect,_ selfFitSize:CGSize)->CGRect)
        ,indicatorSize:CGSize
        ,indicatorHorizonMargin:CGFloat) {
        super.init(frame: CGRect.zero)
        self.adjustFrameClosures = adjustFrameInSuperView
        self.indicatorViewProvider = indicatorProvider
        self.indicatorHorizonMargin = indicatorHorizonMargin
        self.indicatorSize = indicatorSize
        let tap = UITapGestureRecognizer(target: self, action: #selector(tapHandler(_:)))
        self.addGestureRecognizer(tap)
    }
    
    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override public func layoutSubviews() {
        super.layoutSubviews()
        var indicatorX:CGFloat = 0;
        for indicator in self.subviews {
            let tag = indicator.tag
            if tag != -1 {
                indicatorX = CGFloat(tag) * (self.indicatorSize.width + self.indicatorHorizonMargin);
                indicator.frame = CGRect(origin: CGPoint(x:indicatorX,y:0), size: self.indicatorSize)
            }
        }
        self.selectedIndicator.frame = self.indicatorReference[self.currentSelectedIndex]?.frame ?? CGRect.zero
    }

    public func fitFrameInSuperView(_ superViewBounds:CGRect) -> CGRect {
        let normalIndicatorCount =  max((self.subviews.count - 1), 0);
        let marginCount = max((normalIndicatorCount - 1), 0)
        let fitWidth = (self.indicatorSize.width * CGFloat(normalIndicatorCount) + self.indicatorHorizonMargin * CGFloat(marginCount))
        let fitHeight = self.indicatorSize.height
        let viewSize = CGSize(width:fitWidth, height:fitHeight)
        let frame = self.adjustFrameClosures(superViewBounds,viewSize)
        return frame;
    }

    //MARK:private
    private func setupIndicator(_ count:Int) {
        self.currentSelectedIndex = 0
        self.indicatorReference.removeAll()
        for v in self.subviews{
            v.removeFromSuperview()
        }
        for i in 0..<count{
            let normalIndicator = self.indicatorViewProvider(self,.normal)
            normalIndicator.isUserInteractionEnabled = false
            normalIndicator.tag = i
            if (i == self.currentSelectedIndex) {
                normalIndicator.isHidden = true
            }
            self.addSubview(normalIndicator)
            self.indicatorReference[i] = normalIndicator
        }
        let selectedIndicator = self.indicatorViewProvider(self,.selected)
        selectedIndicator.tag = -1
        selectedIndicator.isUserInteractionEnabled = false
        self.addSubview(selectedIndicator)
        self.selectedIndicator = selectedIndicator
        self.indicatorReference[-1] = selectedIndicator
    }

    private func changeSelectedIndicator(_ index:Int){
        if(index >= 0
            && index < self.indicatorCount
            && index != self.currentSelectedIndex){
            self.indicatorReference[self.currentSelectedIndex]?.isHidden = false
            let targetIndicator = self.indicatorReference[index]
            targetIndicator?.isHidden = true
            self.selectedIndicator.frame = targetIndicator?.frame ?? CGRect.zero
            self.selectedIndex = index
        }
    }

    @objc private func tapHandler(_ tap:UITapGestureRecognizer){
        if let onIndicatorClick = self.onIndicatorClicked{
            let touchPoint = tap.location(in: tap.view)
            for view in self.subviews {
                if (view.tag != -1
                    && view.frame.contains(touchPoint)) {
                    onIndicatorClick(self, view.tag, view)
                    break
                }
            }
        }
    }

    /*
    // Only override draw() if you perform custom drawing.
    // An empty implementation adversely affects performance during animation.
    override func draw(_ rect: CGRect) {
        // Drawing code
    }
    */

}

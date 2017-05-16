//
//  ViewController.swift
//  CLCarouselView
//
//  Created by liuchang on 2016/11/8.
//  Copyright © 2016年 com.unknown. All rights reserved.
//

import UIKit

class ViewController: UIViewController {
    let dataSource = [UIColor.red,UIColor.blue,UIColor.orange,UIColor.gray]
    weak var carouselView : AKCarouselView!
    override func viewDidLoad() {
        super.viewDidLoad()
        let screenWidth = UIScreen.main.bounds.size.width
        let indicatorWH:CGFloat = 16
        let carouselPage = AKCarouselPageControl.init(indicatorProvider: { (CLCarouselPageControl, CLCarouselPageControlViewType) in
            let imageV = UIImageView()
            var bgColor = UIColor.gray
            if(CLCarouselPageControlViewType == .selected){
                bgColor = UIColor.red
            }
            imageV.backgroundColor = bgColor
            imageV.clipsToBounds = true
            imageV.layer.cornerRadius = indicatorWH / CGFloat(2)
            return imageV
        }, adjustFrameInSuperView: {superviewBounds,selfFitSize in
            let viewH = superviewBounds.size.height;
            let viewW = superviewBounds.size.width;
            let x = viewW - selfFitSize.width - 10;
            let y = viewH - selfFitSize.height;
            return CGRect(origin: CGPoint(x:x,y:y), size: selfFitSize)
        }, indicatorSize: CGSize(width:indicatorWH,height:indicatorWH), indicatorHorizonMargin: 5)

        carouselPage.onIndicatorClicked = {pageControl,index,view in
            print("pageControl did click index\(index)")
        }

        let carouselView =
        AKCarouselView(frame:  CGRect(x: 0, y: 20, width: screenWidth, height: 200), dataSourceProvider: { [unowned self] view in
            return self.dataSource
        }) { [unowned self] carsouelView,index in
            var view = carsouelView.dequeueReuseView()
            let color = self.dataSource[index]
            if (view == nil){
                view = UIView()
            }
            view?.backgroundColor = color
            return view!
        }
        carouselView.onContentViewSelected = {carouselView,index,view in
            print("onViewSelected index:\(index),view:\(view)")
        }
        carouselView.onContentViewIndexChange = {carouselView,index in
            print("onViewIndexChange is \(index)")
        }
        //1即为 不缩放
        carouselView.contentScale = 0.8
        carouselView.contentHorizonelMargin = 10
        carouselView.autoScrollInterval = 3
        //没有contentSize 即全
        carouselView.contentSize = CGSize(width: 100, height: 100)
        carouselView.pageControl = carouselPage
        self.view .addSubview(carouselView)
        self.carouselView = carouselView;

        

        let btn = UIButton(type: .system)
        btn.setTitle("remove", for: .normal)
        btn.sizeToFit()
        btn .addTarget(self, action: #selector(btnClick), for: .touchUpInside)
        btn.frame.origin = CGPoint(x: 20, y: 250)
        self.view.addSubview(btn)

    }
    func btnClick() {
        self.carouselView?.removeFromSuperview()
    }
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }


}



import UIKit

class TransView:UIImageView
{
    func transformToFitQuadTopLeft(tl:CGPoint,tr:CGPoint,bl:CGPoint,br:CGPoint)
    {
        guard self.layer.anchorPoint == CGPoint.zero  else { print("suck");return }
        
        let b:CGRect = boundingBoxForQuadTR(tl:tl, tr:tr, bl:bl, br:br)
        self.frame = b
        let matrix = rectToQuad( rect: self.bounds,
                                           topLeft: CGPoint(x: tl.x-b.origin.x, y: tl.y-b.origin.y),
                                           topRight: CGPoint(x: tr.x-b.origin.x, y: tr.y-b.origin.y),
                                           bottomLeft: CGPoint(x: bl.x-b.origin.x, y: bl.y-b.origin.y),
                                           bottomRight: CGPoint(x: br.x-b.origin.x, y: br.y-b.origin.y) )
        if self.bounds != CGRect.zero{
            self.layer.transform = matrix
        }
        
        //self.layer.transform = matrix
        
        
    }
    
    func boundingBoxForQuadTR(
        tl:CGPoint,  tr:CGPoint,  bl:CGPoint,  br:CGPoint    )->(CGRect)
    {
        var b:CGRect = CGRect.zero
        
        let xmin:CGFloat = min(min(min(tr.x, tl.x), bl.x),br.x);
        let ymin:CGFloat = min(min(min(tr.y, tl.y), bl.y),br.y);
        let xmax:CGFloat = max(max(max(tr.x, tl.x), bl.x),br.x);
        let ymax:CGFloat = max(max(max(tr.y, tl.y), bl.y),br.y);
        
        b.origin.x = xmin
        b.origin.y = ymin
        b.size.width = xmax - xmin
        b.size.height = ymax - ymin
        
        return b;
    }
    
    func rectToQuad(
        rect:CGRect,
        topLeft:CGPoint,
        topRight:CGPoint,
        bottomLeft:CGPoint,
        bottomRight:CGPoint   )->(CATransform3D)
    {
        return rectToQuad(rect: rect,x1a: topLeft.x, y1a: topLeft.y, x2a: topRight.x, y2a: topRight.y, x3a: bottomLeft.x, y3a: bottomLeft.y, x4a: bottomRight.x, y4a: bottomRight.y)
    }
    
    
    func rectToQuad(
        rect:CGRect,
        x1a:CGFloat, y1a:CGFloat,
        x2a:CGFloat, y2a:CGFloat,
        x3a:CGFloat, y3a:CGFloat,
        x4a:CGFloat, y4a:CGFloat    )->(CATransform3D)
    {
        let X = rect.origin.x;
        let Y = rect.origin.y;
        let W = rect.size.width;
        let H = rect.size.height;

        
        let y21 = y2a - y1a;
        let y32 = y3a - y2a;
        let y43 = y4a - y3a;
        let y14 = y1a - y4a;
        let y31 = y3a - y1a;
        let y42 = y4a - y2a;

        let a = -H*(x2a*x3a*y14 + x2a*x4a*y31 - x1a*x4a*y32 + x1a*x3a*y42);
        let b = W*(x2a*x3a*y14 + x3a*x4a*y21 + x1a*x4a*y32 + x1a*x2a*y43);
        
        // let c = H*X*(x2a*x3a*y14 + x2a*x4a*y31 - x1a*x4a*y32 + x1a*x3a*y42) - H*W*x1a*(x4a*y32 - x3a*y42 + x2a*y43) - W*Y*(x2a*x3a*y14 + x3a*x4a*y21 + x1a*x4a*y32 + x1a*x2a*y43);
        // Could be too long for Swift. Replaced with four lines:
        let c0 = -H*W*x1a*(x4a*y32 - x3a*y42 + x2a*y43)
        let cx = H*X*(x2a*x3a*y14 + x2a*x4a*y31 - x1a*x4a*y32 + x1a*x3a*y42)
        let cy = -W*Y*(x2a*x3a*y14 + x3a*x4a*y21 + x1a*x4a*y32 + x1a*x2a*y43)
        let c = c0 + cx + cy
        
        let d = H*(-x4a*y21*y3a + x2a*y1a*y43 - x1a*y2a*y43 - x3a*y1a*y4a + x3a*y2a*y4a);
        let e = W*(x4a*y2a*y31 - x3a*y1a*y42 - x2a*y31*y4a + x1a*y3a*y42);
        
        // let f = -(W*(x4a*(Y*y2a*y31 + H*y1a*y32) - x3a*(H + Y)*y1a*y42 + H*x2a*y1a*y43 + x2a*Y*(y1a - y3a)*y4a + x1a*Y*y3a*(-y2a + y4a)) - H*X*(x4a*y21*y3a - x2a*y1a*y43 + x3a*(y1a - y2a)*y4a + x1a*y2a*(-y3a + y4a)));
        // Is too long for Swift. Replaced with four lines:
        let f0 = -W*H*(x4a*y1a*y32 - x3a*y1a*y42 + x2a*y1a*y43)
        let fx = H*X*(x4a*y21*y3a - x2a*y1a*y43 - x3a*y21*y4a + x1a*y2a*y43)
        let fy = -W*Y*(x4a*y2a*y31 - x3a*y1a*y42 - x2a*y31*y4a + x1a*y3a*y42)
        let f = f0 + fx + fy
        
        let g = H*(x3a*y21 - x4a*y21 + (-x1a + x2a)*y43);
        let h = W*(-x2a*y31 + x4a*y31 + (x1a - x3a)*y42);
        
        // let i = W*Y*(x2a*y31 - x4a*y31 - x1a*y42 + x3a*y42) + H*(X*(-(x3a*y21) + x4a*y21 + x1a*y43 - x2a*y43) + W*(-(x3a*y2a) + x4a*y2a + x2a*y3a - x4a*y3a - x2a*y4a + x3a*y4a));
        // Is too long for Swift. Replaced with four lines:
        let i0 = H*W*(x3a*y42 - x4a*y32 - x2a*y43)
        let ix = H*X*(x4a*y21 - x3a*y21 + x1a*y43 - x2a*y43)
        let iy = W*Y*(x2a*y31 - x4a*y31 - x1a*y42 + x3a*y42)
        var i = i0 + ix + iy
        
        let kEpsilon:CGFloat = 0.0001;
        if(fabs(i) < kEpsilon) { i = kEpsilon * (i > 0 ? 1.0 : -1.0); }
        
        return CATransform3D(m11:a/i, m12:d/i, m13:0, m14:g/i,
                             m21:b/i, m22:e/i, m23:0, m24:h/i,
                             m31:0, m32:0, m33:1, m34:0,
                             m41:c/i, m42:f/i, m43:0, m44:1.0)
    }
    
}

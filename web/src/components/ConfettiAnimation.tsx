import { useRive, Layout, Fit, Alignment } from '@rive-app/react-canvas';
import confettiAnimation from '../assets/confetti.riv';

interface ConfettiAnimationProps {
  className?: string;
  style?: React.CSSProperties;
}

export const ConfettiAnimation: React.FC<ConfettiAnimationProps> = ({ 
  className, 
  style
}) => {
  const { RiveComponent } = useRive({
    src: confettiAnimation,
    autoplay: true,
    stateMachines: 'State Machine 1',
    layout: new Layout({
      fit: Fit.Cover,
      alignment: Alignment.Center,
    }),
  });

  return (
    <div 
      className={className}
      style={{
        width: '100%',
        height: '100%',
        position: 'absolute',
        top: 0,
        left: 0,
        right: 0,
        bottom: 0,
        ...style
      }}
    >
      <RiveComponent />
    </div>
  );
};

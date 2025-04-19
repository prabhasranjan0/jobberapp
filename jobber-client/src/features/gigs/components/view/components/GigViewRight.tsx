import { FC, ReactElement, useContext } from 'react';

import GigPackage from './GigViewRight/GigPackage';
import GigRelatedTags from './GigViewRight/GigRelatedTags';
import GigSeller from './GigViewRight/GigSeller';
import { GigContext } from 'src/features/gigs/context/GigContext';

const GigViewRight: FC = (): ReactElement => {
  const { seller } = useContext(GigContext);
  return (
    <>
      <GigPackage />
      {seller && <GigSeller />}
      <GigRelatedTags />
    </>
  );
};

export default GigViewRight;

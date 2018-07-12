import * as React from 'react';
import { storiesOf } from '@storybook/react';
import { Component1 } from './component1';
import { Component2 } from './component2';

storiesOf('Component 1', module)
  .add('testing', () => (
    <Component1 />
  ))

storiesOf('Component 2', module)
  .add('testing', () => (
    <Component2 />
  ))

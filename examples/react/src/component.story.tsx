import * as React from 'react';
import { storiesOf } from '@storybook/react';
import { Component } from './component';

storiesOf('Component', module)
  .add('testing', () => (
    <Component />
  ))

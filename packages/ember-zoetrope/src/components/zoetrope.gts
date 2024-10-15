import { hash } from '@ember/helper';
import { on } from '@ember/modifier';
import { throttle } from '@ember/runloop';
import Component from '@glimmer/component';
import { tracked } from '@glimmer/tracking';
import { modifier } from 'ember-modifier';
import { local } from 'embroider-css-modules';

import { getRelativeBoundingClientRect } from '../utils.ts';
import styles from './zoetrope.css';

interface ZoetropeSignature {
  Args: {
    gap: number;
    offset: number;
  };
  Blocks: {
    content: [];
    controls: [
      {
        canScroll: boolean;
        cannotScrollLeft: boolean;
        cannotScrollRight: boolean;
        scrollLeft: () => void;
        scrollRight: () => void;
      },
    ];
    header: [];
  };
  Element: HTMLElement;
}

const DEFAULT_GAP = 8;
const DEFAULT_OFFSET = 0;

export default class ZoetropeComponent extends Component<ZoetropeSignature> {
  @tracked currentlyScrolled = 0;
  @tracked scrollWidth = 0;
  @tracked offsetWidth = 0;
  @tracked scrollerElement: HTMLElement | null = null;
  @tracked scrollContentElement: HTMLElement | null = null;

  private zoetropeModifier = modifier(
    (
      element: HTMLElement,
      _,
      { gap, offset }: { gap: number; offset: number },
    ) => {
      this.scrollerElement = element.querySelector(`.${styles.scroller}`);
      this.scrollContentElement = element.querySelector(
        `.${styles['scroll-content']}`,
      );

      if (!this.scrollerElement || !this.scrollContentElement) {
        throw new Error('scrollContentElement or scrollerElement not found');
      }

      const zoetropeResizeObserver = new ResizeObserver(() => {
        if (!this.scrollerElement) {
          return;
        }

        this.scrollWidth = this.scrollerElement.scrollWidth;
        this.offsetWidth = this.scrollerElement.offsetWidth;
      });

      zoetropeResizeObserver.observe(element);

      this.currentlyScrolled = this.scrollerElement.scrollLeft;

      element.style.setProperty('--zoetrope-gap', `${gap}px`);

      element.style.setProperty('--zoetrope-offset', `${offset}px`);

      this.scrollerElement.addEventListener('scroll', this.scrollListener);

      return () => {
        this.scrollerElement?.removeEventListener(
          'scroll',
          this.scrollListener,
        );

        zoetropeResizeObserver.unobserve(element);
      };
    },
  );

  // eslint-disable-next-line ember/no-runloop
  private scrollListener = () => throttle(this, this.handleScroll, 16, true);

  private handleScroll = () => {
    this.currentlyScrolled = this.scrollerElement?.scrollLeft || 0;
  };

  get offset() {
    return this.args.offset ?? DEFAULT_OFFSET;
  }

  get gap() {
    return this.args.gap ?? DEFAULT_GAP;
  }

  get canScroll() {
    return this.scrollWidth > this.offsetWidth + this.offset;
  }

  get cannotScrollLeft() {
    return this.currentlyScrolled <= this.offset;
  }

  get cannotScrollRight() {
    return (
      this.scrollWidth - this.offsetWidth - this.offset < this.currentlyScrolled
    );
  }

  scrollLeft = () => {
    if (
      !(this.scrollerElement instanceof HTMLElement) ||
      !this.scrollContentElement
    ) {
      return;
    }

    const { firstChild } = this.findOverflowingElement();

    if (!firstChild) {
      return;
    }

    const children = [...this.scrollContentElement.children];

    const firstChildIndex = children.indexOf(firstChild);

    let targetElement = firstChild;
    let accumalatedWidth = 0;

    for (let i = firstChildIndex; i >= 0; i--) {
      const child = children[i];

      if (!(child instanceof HTMLElement)) {
        continue;
      }

      accumalatedWidth += child.offsetWidth + this.gap;

      if (accumalatedWidth >= this.offsetWidth) {
        break;
      }

      targetElement = child;
    }

    const rect = getRelativeBoundingClientRect(
      targetElement,
      this.scrollerElement,
    );

    this.scrollerElement.scrollBy({
      left: rect.left - this.offset,
      behavior: 'smooth',
    });
  };

  lastRightElement: Element | undefined;
  scrollRight = () => {
    if (
      !(this.scrollerElement instanceof HTMLElement) ||
      !this.scrollContentElement
    ) {
      return;
    }

    const { activeSlide, lastChild } = this.findOverflowingElement();
    if (!lastChild) {
      return;
    }

    let rect = getRelativeBoundingClientRect(lastChild, this.scrollerElement);

    // If the card is large than the container then skip to the next card
    // we cache the last element so we don't skip it immediately
    if (rect.width > this.offsetWidth && activeSlide === lastChild) {
      const children = [...this.scrollContentElement.children];
      const lastChildIndex = children.indexOf(lastChild);
      const targetElement = children[lastChildIndex + 1];
      if (!targetElement) {
        return;
      }
      rect = getRelativeBoundingClientRect(targetElement, this.scrollerElement);
    }

    this.lastRightElement = lastChild;
    this.scrollerElement?.scrollBy({
      left: rect.left - this.offset,
      behavior: 'smooth',
    });
  };

  private findOverflowingElement() {
    const returnObj: {
      activeSlide?: Element;
      firstChild?: Element;
      lastChild?: Element;
    } = {
      firstChild: undefined,
      lastChild: undefined,
      activeSlide: undefined,
    };

    if (!this.scrollerElement || !this.scrollContentElement) {
      return returnObj;
    }

    const parentElement = this.scrollerElement.parentElement;

    if (!parentElement) {
      return returnObj;
    }

    const containerRect = getRelativeBoundingClientRect(
      this.scrollerElement,
      parentElement,
    );

    const children = [...this.scrollContentElement.children];

    for (const child of children) {
      const rect = getRelativeBoundingClientRect(child, this.scrollerElement!);

      if (
        rect.right + this.gap >= containerRect.left &&
        !returnObj.firstChild
      ) {
        returnObj.firstChild = child;
      }

      if (rect.left >= this.offset && !returnObj.activeSlide) {
        returnObj.activeSlide = child;
      }

      if (rect.right >= containerRect.width && !returnObj.lastChild) {
        returnObj.lastChild = child;
        break;
      }
    }

    if (!returnObj.firstChild) {
      returnObj.firstChild = children[0];
    }

    if (!returnObj.lastChild) {
      returnObj.lastChild = children[children.length - 1];
    }

    return returnObj;
  }

  <template>
    <div
      class="zoetrope"
      {{this.zoetropeModifier gap=this.gap offset=this.offset}}
    >
      <div class="zoetrope-header">
        {{yield to="header"}}
      </div>
      <div class="zoetrope-controls">
        {{#if (has-block "controls")}}
          {{yield
            (hash
              cannotScrollLeft=this.cannotScrollLeft
              cannotScrollRight=this.cannotScrollRight
              canScroll=this.canScroll
              scrollLeft=this.scrollLeft
              scrollRight=this.scrollRight
            )
            to="controls"
          }}
        {{else}}
          {{#if this.canScroll}}
            <div>
              <button
                type="button"
                {{on "click" this.scrollLeft}}
                disabled={{this.cannotScrollLeft}}
              >Left</button>

              <button
                type="button"
                {{on "click" this.scrollRight}}
                disabled={{this.cannotScrollRight}}
              >Right</button>
            </div>
          {{/if}}
        {{/if}}
      </div>
      <div class={{local styles "scroller"}}>
        <div class={{local styles "scroll-content"}}>
          {{yield to="content"}}
        </div>
      </div>
    </div>
  </template>
}

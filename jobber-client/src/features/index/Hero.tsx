import { ChangeEvent, FC, FormEvent, ReactElement, RefObject, useEffect, useRef, useState } from 'react';
import { createSearchParams, NavigateFunction, useNavigate, Link } from 'react-router-dom';
import Typed from 'typed.js';
import { v4 as uuidv4 } from 'uuid';
import { FaSearch } from 'react-icons/fa';
import Button from 'src/shared/button/Button';
import TextInput from 'src/shared/inputs/TextInput';
import { replaceSpacesWithDash } from 'src/shared/utils/utils.service';

const categories: string[] = ['Graphics & Design', 'Digital Marketing', 'Writing & Translation', 'Programming & Tech'];

const Hero: FC = (): ReactElement => {
  const typedElement: RefObject<HTMLSpanElement> = useRef<HTMLSpanElement>(null);
  const [searchTerm, setSearchTerm] = useState<string>('');
  const navigate: NavigateFunction = useNavigate();

  const navigateToSearchPage = (): void => {
    const url = `/gigs/search?${createSearchParams({ query: searchTerm.trim() })}`;
    navigate(url);
  };

  useEffect(() => {
    const typed = new Typed(typedElement.current, {
      strings: [...categories, 'Video & Animation'],
      startDelay: 300,
      typeSpeed: 120,
      backSpeed: 200,
      backDelay: 300
    });

    return () => {
      typed.destroy();
    };
  }, []);

  return (
    <div className="relative pb-20 pt-40 bg-gradient-to-b from-[#0A2647] to-[#205295] dark:bg-gradient-to-b dark:from-bg-brand-darkBlue dark:to-bg-brand-blueSecondary lg:pt-44">
      <div className="relative m-auto px-6 xl:container md:px-12 lg:px-6">
        <h3 className="mb-4 mt-4 max-w-2xl pb-2 text-center text-2xl font-normal dark:text-white lg:text-left">
          Expert categories: <span ref={typedElement}></span>
        </h3>
        <h1 className="text-center text-4xl font-black text-blue-900 dark:text-white sm:mx-auto sm:w-10/12 sm:text-5xl md:w-10/12 md:text-5xl lg:w-auto lg:text-left xl:text-7xl">
          Start Your Next Project <br className="hidden lg:block" />
          <span className="relative bg-gradient-to-r from-blue-600 to-cyan-500 bg-clip-text text-transparent dark:from-brand-bluePrimary dark:to-brand-lightSecondary">
            with the Best Talent.
          </span>
        </h1>
        <div className="lg:flex">
          <div className="relative mt-8 space-y-8 text-center sm:mx-auto sm:w-10/12 md:mt-16 md:w-2/3 lg:ml-0 lg:mr-auto lg:w-7/12 lg:text-left">
            <p className="text-gray-700 dark:text-gray-300 sm:text-lg lg:w-11/12">
              {`Connect with skilled freelancers for your next big idea.`}
            </p>
            <div className="flex w-full justify-between gap-6 lg:gap-12">
              <form
                className="mx-auto flex w-full items-center bg-white rounded-full gap-1 pl-1 pr-1 h-14"
                onSubmit={(event: FormEvent) => {
                  event.preventDefault();
                  navigateToSearchPage();
                }}
              >
                <div className="w-full h-12">
                  <TextInput
                    type="search"
                    className="w-full h-full flex rounded-full px-4 py-1 text-gray-800 focus:outline-none"
                    placeholder="Search"
                    value={searchTerm}
                    onChange={(event: ChangeEvent) => {
                      setSearchTerm((event.target as HTMLInputElement).value);
                    }}
                  />
                </div>
                <div className="bg-brand-bluePrimary rounded-full mt-1 mb-1">
                  <Button
                    type="submit"
                    className="flex h-12 w-12 items-center justify-center text-white"
                    label={<FaSearch className="h-5 w-5" />}
                    onClick={navigateToSearchPage}
                  />
                </div>
              </form>
            </div>

            <div className="grid grid-cols-3 gap-x-2 gap-y-4 sm:flex sm:justify-center lg:justify-start">
              {categories.map((category: string) => (
                <div
                  key={uuidv4()}
                  className="w-full min-w-0 cursor-pointer rounded-md border border-gray-200 p-4 duration-300 hover:shadow-lg hover:shadow-cyan-600/20 dark:border-gray-700 dark:bg-gray-800 dark:hover:border-brand-lightBlue hover:scale-105 hover:border-b-4 hover:border-cyan-400 transition-all"
                >
                  <div className="flex justify-center">
                    <span className="block truncate font-medium dark:text-white">
                      <Link to={`/search/categories/${replaceSpacesWithDash(category)}`}>{category}</Link>
                    </span>
                  </div>
                </div>
              ))}
            </div>
          </div>
          <div className="-right-10 hidden lg:col-span-2 lg:mt-0 lg:flex">
            <div className="relative w-full">
              <img
                src="https://www.dynodesoft.com/assets/images/icons/mobile-app-dev.png"
                className="relative w-full"
                alt=""
                loading="lazy"
              />
            </div>
          </div>
        </div>
      </div>
    </div>
  );
};

export default Hero;
